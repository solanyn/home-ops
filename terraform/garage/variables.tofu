variable "buckets" {
  type        = list(string)
  description = "S3 buckets to create"
}

variable "GARAGE_ADMIN_TOKEN" {
  type        = string
  description = "Garage admin API token"
  sensitive   = true
}

variable "GARAGE_ADMIN_URL" {
  type        = string
  description = "Garage admin API URL"
  default     = "garage-admin.goyangi.io"
}

variable "GARAGE_ROOT_ACCESS_KEY_ID" {
  type        = string
  description = "Garage root access key ID"
}
