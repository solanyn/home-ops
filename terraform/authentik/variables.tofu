variable "OP_CONNECT_HOST" {
  type        = string
  description = "OnePassword Connect URL"
}

variable "OP_CONNECT_TOKEN" {
  type        = string
  description = "OnePassword Connect token"
  sensitive   = true
}

variable "CLUSTER_DOMAIN" {
  type        = string
  description = "Cluster domain"
  default     = "goyangi.io"
}

variable "applications" {
  type = map(object({
    group         = string
    icon          = string
    redirect_uris = list(string)
    public        = optional(bool, false)
  }))
  description = "OIDC applications to create"
}
