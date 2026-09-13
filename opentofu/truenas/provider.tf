provider "truenas" {
  host        = var.truenas_host
  auth_method = "websocket"

  ssh {
    port                 = var.truenas_ssh_port
    user                 = var.truenas_ssh_user
    private_key          = var.truenas_ssh_private_key
    host_key_fingerprint = var.truenas_ssh_host_key_fingerprint
  }

  websocket {
    username = var.truenas_ssh_user
    api_key  = var.truenas_api_key
  }
}
