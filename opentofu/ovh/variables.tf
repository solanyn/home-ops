variable "vps_display_name" {
    type        = string
    description = "Custom display name for the VPS."
    default     = "edge"
}

variable "vps_plan_code" {
    type        = string
    description = "OVH VPS plan code to order."
    default     = "vps-2027-model1"
}

variable "vps_datacenter" {
    type        = string
    description = "Datacenter for the VPS."
    default     = "SYD"
}

variable "vps_os" {
    type        = string
    description = "Operating system to install on the VPS."
    default     = "Debian 13"
}
