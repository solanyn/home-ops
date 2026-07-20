provider "unifi" {
    api_url        = var.unifi_api_url
    allow_insecure = var.unifi_insecure
    site           = var.unifi_site
}