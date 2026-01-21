terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    onepassword = {
      source  = "1Password/onepassword"
      version = "~> 2.0"
    }
  }
}

provider "google" {
  project     = var.GCP_PROJECT
  region      = var.GCP_REGION
  credentials = var.GCP_CREDENTIALS
}

provider "helm" {
  alias = "worker"
  kubernetes {
    host                   = "https://${google_container_cluster.worker.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.worker.master_auth[0].cluster_ca_certificate)
  }
}

provider "kubernetes" {
  alias = "worker"
  host                   = "https://${google_container_cluster.worker.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.worker.master_auth[0].cluster_ca_certificate)
}

provider "kubernetes" {
  alias = "master"
}

provider "onepassword" {
  service_account_token = var.OP_SERVICE_ACCOUNT_TOKEN
}

data "google_client_config" "default" {}

resource "google_container_cluster" "worker" {
  name     = var.GKE_CLUSTER_NAME
  location = var.GCP_ZONE

  initial_node_count       = 1
  remove_default_node_pool = true

  cluster_autoscaling {
    autoscaling_profile = "OPTIMIZE_UTILIZATION"
  }

  # Disable all GCP managed services
  logging_service    = "none"
  monitoring_service = "none"
  
  # Disable addons we don't need
  addons_config {
    http_load_balancing {
      disabled = true
    }
    horizontal_pod_autoscaling {
      disabled = true  # We use Kueue instead
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true  # Keep for GPU node boot disks
    }
  }
}

resource "google_container_node_pool" "system" {
  name     = "system"
  cluster  = google_container_cluster.worker.name
  location = var.GCP_ZONE

  node_count = 1

  node_config {
    machine_type = "e2-micro"
    disk_size_gb = 20
    disk_type    = "pd-standard"
    spot         = true
  }
}

resource "google_container_node_pool" "gpu" {
  name     = "gpu"
  cluster  = google_container_cluster.worker.name
  location = var.GCP_ZONE

  autoscaling {
    min_node_count = 0
    max_node_count = var.GPU_MAX_NODES
  }

  node_config {
    machine_type = var.GPU_MACHINE_TYPE
    disk_size_gb = 100
    disk_type    = "pd-ssd"
    spot         = true

    guest_accelerator {
      type               = var.GPU_TYPE
      count              = 1
      gpu_driver_installation_config {
        gpu_driver_version = "LATEST"
      }
    }
  }
}

resource "google_container_node_pool" "cpu" {
  name     = "cpu"
  cluster  = google_container_cluster.worker.name
  location = var.GCP_ZONE

  autoscaling {
    min_node_count = 0
    max_node_count = var.CPU_MAX_NODES
  }

  node_config {
    machine_type = "e2-medium"
    disk_size_gb = 100
    disk_type    = "pd-ssd"
    spot         = true
  }
}

# Wireguard keypairs - pre-generated and stored in 1Password
# Generate with: wg genkey | tee private.key | wg pubkey > public.key

resource "helm_release" "liqo" {
  provider         = helm.worker
  name             = "liqo"
  namespace        = "liqo-system"
  create_namespace = true
  repository       = "https://helm.liqo.io"
  chart            = "liqo"

  set {
    name  = "discovery.config.clusterID"
    value = var.WORKER_CLUSTER_ID
  }

  set {
    name  = "networking.internal.podCIDR"
    value = google_container_cluster.worker.cluster_ipv4_cidr
  }

  set {
    name  = "networking.internal.serviceCIDR"
    value = google_container_cluster.worker.services_ipv4_cidr
  }

  depends_on = [google_container_node_pool.system]
}

# Wireguard secret for GKE gateway client (worker's keypair)
resource "kubernetes_secret" "wireguard_worker" {
  provider = kubernetes.worker
  metadata {
    name      = "wireguard-keys"
    namespace = kubernetes_namespace.liqo_tenant_home.metadata[0].name
    labels = {
      "liqo.io/remote-cluster-id"           = var.MASTER_CLUSTER_ID
      "networking.liqo.io/gateway-resource" = "true"
    }
  }
  data = {
    privateKey = var.WG_WORKER_PRIVATE_KEY
    publicKey  = var.WG_WORKER_PUBLIC_KEY
  }
}

# PublicKey CR for home cluster's public key (on worker)
resource "kubernetes_manifest" "publickey_master" {
  provider = kubernetes.worker
  manifest = {
    apiVersion = "networking.liqo.io/v1beta1"
    kind       = "PublicKey"
    metadata = {
      name      = "master"
      namespace = kubernetes_namespace.liqo_tenant_home.metadata[0].name
      labels = {
        "liqo.io/remote-cluster-id"           = var.MASTER_CLUSTER_ID
        "networking.liqo.io/gateway-resource" = "true"
      }
    }
    spec = {
      publicKey = var.WG_MASTER_PUBLIC_KEY
    }
  }
  depends_on = [helm_release.liqo]
}

# GatewayClient CR - connects to home cluster's GatewayServer
resource "kubernetes_manifest" "gateway_client" {
  provider = kubernetes.worker
  manifest = {
    apiVersion = "networking.liqo.io/v1beta1"
    kind       = "GatewayClient"
    metadata = {
      name      = "master"
      namespace = kubernetes_namespace.liqo_tenant_home.metadata[0].name
      labels = {
        "liqo.io/remote-cluster-id" = var.MASTER_CLUSTER_ID
      }
    }
    spec = {
      clientTemplateRef = {
        apiVersion = "networking.liqo.io/v1beta1"
        kind       = "WgGatewayClientTemplate"
        name       = "wireguard-client"
        namespace  = "liqo-system"
      }
      secretRef = {
        name = kubernetes_secret.wireguard_worker.metadata[0].name
      }
      endpoint = {
        addresses = [var.MASTER_GATEWAY_IP]
        port      = 51840
        protocol  = "UDP"
      }
      mtu = 1340
    }
  }
  depends_on = [helm_release.liqo]
}

# Tenant namespace for home cluster peering
resource "kubernetes_namespace" "liqo_tenant_home" {
  provider = kubernetes.worker
  metadata {
    name = "liqo-tenant-master"
    labels = {
      "liqo.io/remote-cluster-id"  = var.MASTER_CLUSTER_ID
      "liqo.io/tenant-namespace"   = "true"
    }
  }
  depends_on = [helm_release.liqo]
}

# ServiceAccount for home cluster to access worker
resource "kubernetes_service_account" "liqo_consumer" {
  provider = kubernetes.worker
  metadata {
    name      = "liqo-consumer"
    namespace = kubernetes_namespace.liqo_tenant_home.metadata[0].name
  }
}

# Long-lived token for the SA
resource "kubernetes_secret" "liqo_consumer_token" {
  provider = kubernetes.worker
  metadata {
    name      = "liqo-consumer-token"
    namespace = kubernetes_namespace.liqo_tenant_home.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.liqo_consumer.metadata[0].name
    }
  }
  type = "kubernetes.io/service-account-token"
}

# RoleBinding for consumer to manage Liqo resources
resource "kubernetes_role_binding" "liqo_consumer" {
  provider = kubernetes.worker
  metadata {
    name      = "liqo-consumer"
    namespace = kubernetes_namespace.liqo_tenant_home.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "liqo-remote-controlplane"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.liqo_consumer.metadata[0].name
    namespace = kubernetes_namespace.liqo_tenant_home.metadata[0].name
  }
}

# Tenant CR to accept ResourceSlices from home cluster
resource "kubernetes_manifest" "liqo_tenant" {
  provider = kubernetes.worker
  manifest = {
    apiVersion = "authentication.liqo.io/v1beta1"
    kind       = "Tenant"
    metadata = {
      name      = "master"
      namespace = kubernetes_namespace.liqo_tenant_home.metadata[0].name
      labels = {
        "liqo.io/remote-cluster-id" = var.MASTER_CLUSTER_ID
      }
    }
    spec = {
      clusterID       = var.MASTER_CLUSTER_ID
      authzPolicy     = "TolerateNoHandshake"
      tenantCondition = "Active"
    }
  }
  depends_on = [helm_release.liqo]
}

locals {
  worker_kubeconfig = yamlencode({
    apiVersion = "v1"
    kind       = "Config"
    clusters = [{
      name = "worker"
      cluster = {
        server                     = "https://${google_container_cluster.worker.endpoint}"
        certificate-authority-data = google_container_cluster.worker.master_auth[0].cluster_ca_certificate
      }
    }]
    users = [{
      name = "liqo-consumer"
      user = {
        token = kubernetes_secret.liqo_consumer_token.data["token"]
      }
    }]
    contexts = [{
      name = "worker"
      context = {
        cluster   = "worker"
        user      = "liqo-consumer"
        namespace = kubernetes_namespace.liqo_tenant_home.metadata[0].name
      }
    }]
    current-context = "worker"
  })
}

# Push worker cluster info to 1Password
data "onepassword_vault" "kubernetes" {
  name = "kubernetes"
}

resource "onepassword_item" "worker_cluster" {
  vault    = data.onepassword_vault.kubernetes.uuid
  title    = "worker-cluster"
  category = "secure_note"

  section {
    label = "cluster"
    field {
      label = "CLUSTER_ID"
      type  = "CONCEALED"
      value = var.WORKER_CLUSTER_ID
    }
    field {
      label = "POD_CIDR"
      type  = "CONCEALED"
      value = google_container_cluster.worker.cluster_ipv4_cidr
    }
    field {
      label = "EXTERNAL_CIDR"
      type  = "CONCEALED"
      value = "10.70.0.0/16"
    }
    field {
      label = "kubeconfig"
      type  = "CONCEALED"
      value = local.worker_kubeconfig
    }
    field {
      label = "WG_PUBLIC_KEY"
      type  = "CONCEALED"
      value = var.WG_WORKER_PUBLIC_KEY
    }
    field {
      label = "MASTER_WG_PRIVATE_KEY"
      type  = "CONCEALED"
      value = var.WG_MASTER_PRIVATE_KEY
    }
    field {
      label = "MASTER_WG_PUBLIC_KEY"
      type  = "CONCEALED"
      value = var.WG_MASTER_PUBLIC_KEY
    }
  }
}


# Network Configuration for home cluster (home's CIDRs)
resource "kubernetes_manifest" "liqo_configuration_home" {
  provider = kubernetes.worker
  manifest = {
    apiVersion = "networking.liqo.io/v1beta1"
    kind       = "Configuration"
    metadata = {
      name      = "master"
      namespace = kubernetes_namespace.liqo_tenant_home.metadata[0].name
      labels = {
        "liqo.io/remote-cluster-id" = var.MASTER_CLUSTER_ID
      }
    }
    spec = {
      remote = {
        cidr = {
          pod      = var.MASTER_POD_CIDR
          external = "10.60.0.0/16"
        }
      }
    }
  }
  depends_on = [helm_release.liqo]
}
