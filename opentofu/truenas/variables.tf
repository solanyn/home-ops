variable "truenas_host" {
  description = "TrueNAS host reachable from the tofu-controller runner."
  type        = string
  default     = "nas.internal"
}

variable "truenas_ssh_user" {
  description = "TrueNAS SSH user used by the provider."
  type        = string
  default     = "root"
}

variable "truenas_ssh_port" {
  description = "TrueNAS SSH port."
  type        = number
  default     = 22
}

variable "truenas_ssh_private_key" {
  description = "Private key content for the TrueNAS provider."
  type        = string
  sensitive   = true
}

variable "truenas_ssh_host_key_fingerprint" {
  description = "Pinned TrueNAS SSH host-key fingerprint."
  type        = string
  sensitive   = true
}

variable "onepassword_credentials_json" {
  description = "1Password Connect credentials JSON."
  type        = string
  sensitive   = true
}

variable "onepassword_connect_token" {
  description = "1Password Connect API token."
  type        = string
  sensitive   = true
}

variable "truenas_api_key" {
  description = "TrueNAS API key for WebSocket authentication."
  type        = string
  sensitive   = true
}
