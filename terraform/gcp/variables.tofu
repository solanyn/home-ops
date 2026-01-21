variable "GCP_PROJECT" {
  type        = string
  description = "GCP project ID"
  sensitive   = true
}

variable "GCP_CREDENTIALS" {
  type        = string
  description = "GCP service account JSON"
  sensitive   = true
}

variable "OP_SERVICE_ACCOUNT_TOKEN" {
  type        = string
  description = "1Password service account token"
  sensitive   = true
}

variable "MASTER_CLUSTER_ID" {
  type        = string
  description = "Master cluster ID for Liqo peering"
  default     = "master"
}

variable "WORKER_CLUSTER_ID" {
  type        = string
  description = "Worker cluster ID for Liqo peering"
  default     = "worker"
}

variable "MASTER_POD_CIDR" {
  type        = string
  description = "Master cluster pod CIDR"
  default     = "10.42.0.0/16"
}

variable "GKE_CLUSTER_NAME" {
  type        = string
  description = "GKE cluster name"
  default     = "worker"
}

variable "GCP_REGION" {
  type        = string
  description = "GCP region"
  default     = "asia-southeast1"
}

variable "GCP_ZONE" {
  type        = string
  description = "GCP zone for zonal cluster"
  default     = "asia-southeast1-b"
}

variable "GPU_TYPE" {
  type        = string
  description = "GPU accelerator type"
  default     = "nvidia-l4"
}

variable "GPU_MACHINE_TYPE" {
  type        = string
  description = "Machine type for GPU nodes"
  default     = "g2-standard-8"
}

variable "GPU_MAX_NODES" {
  type        = number
  description = "Max GPU nodes for autoscaling"
  default     = 8
}

variable "CPU_MAX_NODES" {
  type        = number
  description = "Max CPU nodes for autoscaling"
  default     = 4
}

variable "BILLING_ACCOUNT_ID" {
  type        = string
  description = "GCP billing account ID"
  sensitive   = true
}

variable "BUDGET_AMOUNT" {
  type        = number
  description = "Monthly budget in USD"
  default     = 20
}

variable "PUSHOVER_USER_KEY" {
  type        = string
  description = "Pushover user key for alerts"
  sensitive   = true
}

variable "PUSHOVER_API_TOKEN" {
  type        = string
  description = "Pushover API token for alerts"
  sensitive   = true
}

variable "WG_WORKER_PRIVATE_KEY" {
  type        = string
  description = "Wireguard private key for worker cluster"
  sensitive   = true
}

variable "WG_WORKER_PUBLIC_KEY" {
  type        = string
  description = "Wireguard public key for worker cluster"
  sensitive   = true
}

variable "WG_MASTER_PRIVATE_KEY" {
  type        = string
  description = "Wireguard private key for master cluster"
  sensitive   = true
}

variable "WG_MASTER_PUBLIC_KEY" {
  type        = string
  description = "Wireguard public key for master cluster"
  sensitive   = true
}


variable "MASTER_GATEWAY_IP" {
  type        = string
  description = "Home cluster gateway IP (external/public IP for Liqo Wireguard)"
  sensitive   = true
}
