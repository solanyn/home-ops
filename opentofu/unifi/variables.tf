variable "unifi_api_url" {
    type        = string
    description = "Base URL of the UniFi controller (no /api path)."
    default     = "https://192.168.10.1"
}

variable "unifi_insecure" {
    type        = bool
    description = "Skip TLS verification for the controller API."
    default     = true
}

variable "unifi_site" {
    type        = string
    description = "UniFi site name. Defaults to the controller's default site."
    default     = "default"
}