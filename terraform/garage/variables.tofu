variable "buckets" {
  type        = list(string)
  description = "S3 buckets to create"
}

variable "AWS_ACCESS_KEY_ID" {
  type        = string
  description = "Garage access key"
  sensitive   = true
}

variable "AWS_SECRET_ACCESS_KEY" {
  type        = string
  description = "Garage secret key"
  sensitive   = true
}

variable "GARAGE_URL" {
  type        = string
  description = "Garage S3 API URL"
  default     = "garage.storage.svc.cluster.local:3900"
}
