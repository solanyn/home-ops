resource "truenas_app" "doco_cd" {
  name           = "doco-cd"
  custom_app     = true
  compose_config = file("${path.module}/doco-cd-compose.yaml")
  desired_state  = "running"

  restart_triggers = {
    compose_checksum = sha256(file("${path.module}/doco-cd-compose.yaml"))
  }

  depends_on = [
    truenas_dataset.doco_cd,
    truenas_dataset.onepassword_connect,
    truenas_dataset.onepassword_connect_data,
    truenas_file.onepassword_credentials,
    truenas_file.onepassword_token,
    truenas_file.doco_cd_webhook_secret,
  ]
}
