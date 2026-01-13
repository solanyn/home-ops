terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
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

resource "helm_release" "liqo" {
  provider         = helm.worker
  name             = "liqo"
  namespace        = "liqo-system"
  create_namespace = true
  repository       = "https://helm.liqo.io"
  chart            = "liqo"

  set {
    name  = "networking.gatewayTemplates.server.service.type"
    value = "NodePort"
  }

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

# Get node IP for gateway endpoint
data "kubernetes_nodes" "worker" {
  provider = kubernetes.worker
  depends_on = [google_container_node_pool.system]
}

locals {
  worker_node_ip = [for addr in data.kubernetes_nodes.worker.nodes[0].status[0].addresses : addr.address if addr.type == "ExternalIP"][0]
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
      label = "NODE_IP"
      type  = "CONCEALED"
      value = local.worker_node_ip
    }
    field {
      label = "NODE_PORT"
      type  = "CONCEALED"
      value = tostring(data.kubernetes_service.liqo_gateway.spec[0].port[0].node_port)
    }
    field {
      label = "POD_CIDR"
      type  = "CONCEALED"
      value = google_container_cluster.worker.cluster_ipv4_cidr
    }
    field {
      label = "SERVICE_CIDR"
      type  = "CONCEALED"
      value = google_container_cluster.worker.services_ipv4_cidr
    }
    field {
      label = "kubeconfig"
      type  = "CONCEALED"
      value = local.worker_kubeconfig
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

# Gateway server is created automatically by Liqo helm chart
# We just need to get the NodePort for the home cluster to connect
data "kubernetes_service" "liqo_gateway" {
  provider = kubernetes.worker
  metadata {
    name      = "liqo-gateway"
    namespace = "liqo-system"
  }
  depends_on = [helm_release.liqo]
}


# Budget alerts
resource "google_pubsub_topic" "budget_alerts" {
  name    = "gke-worker-budget-alerts"
  project = var.GCP_PROJECT
}

resource "google_billing_budget" "gke_worker" {
  billing_account = var.BILLING_ACCOUNT_ID
  display_name    = "GKE Worker"

  budget_filter {
    projects = ["projects/${var.GCP_PROJECT}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.BUDGET_AMOUNT)
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 0.8
  }
  threshold_rules {
    threshold_percent = 1.0
  }

  all_updates_rule {
    pubsub_topic = google_pubsub_topic.budget_alerts.id
  }
}

resource "google_cloudfunctions_function" "budget_alert" {
  name        = "gke-worker-budget-alert"
  project     = var.GCP_PROJECT
  region      = var.GCP_REGION
  runtime     = "python312"
  entry_point = "handle_budget_alert"

  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = google_pubsub_topic.budget_alerts.id
  }

  source_archive_bucket = google_storage_bucket.functions.name
  source_archive_object = google_storage_bucket_object.budget_alert_function.name

  environment_variables = {
    PUSHOVER_USER_KEY  = var.PUSHOVER_USER_KEY
    PUSHOVER_API_TOKEN = var.PUSHOVER_API_TOKEN
  }
}

resource "google_storage_bucket" "functions" {
  name     = "${var.GCP_PROJECT}-functions"
  project  = var.GCP_PROJECT
  location = var.GCP_REGION
}

resource "google_storage_bucket_object" "budget_alert_function" {
  name   = "budget-alert.zip"
  bucket = google_storage_bucket.functions.name
  source = data.archive_file.budget_alert.output_path
}

data "archive_file" "budget_alert" {
  type        = "zip"
  output_path = "${path.module}/budget-alert.zip"

  source {
    content  = <<-EOF
import base64
import json
import os
import urllib.request

def handle_budget_alert(event, context):
    data = json.loads(base64.b64decode(event['data']).decode('utf-8'))
    budget = data.get('budgetDisplayName', 'Unknown')
    cost = data.get('costAmount', 0)
    threshold = data.get('alertThresholdExceeded', 0)
    
    message = f"GCP Budget Alert: {budget}\nCost: ${cost:.2f}\nThreshold: {threshold*100:.0f}%"
    
    urllib.request.urlopen(
        urllib.request.Request(
            "https://api.pushover.net/1/messages.json",
            data=json.dumps({
                "token": os.environ["PUSHOVER_API_TOKEN"],
                "user": os.environ["PUSHOVER_USER_KEY"],
                "message": message,
                "title": "GCP Budget Alert"
            }).encode(),
            headers={"Content-Type": "application/json"}
        )
    )
EOF
    filename = "main.py"
  }
}
