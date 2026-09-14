resource "random_password" "doco_cd_webhook_secret" {
  length  = 32
  special = false
}

resource "truenas_dataset" "doco_cd" {
  pool        = "world"
  path        = "doco-cd"
  compression = "LZ4"
}

moved {
  from = truenas_dataset.onepassword_connect
  to   = truenas_dataset.onepassword_connect_legacy
}

moved {
  from = truenas_dataset.onepassword_connect_data
  to   = truenas_dataset.onepassword_connect_data_legacy
}

resource "truenas_dataset" "onepassword_connect_legacy" {
  pool          = "world"
  path          = "onepassword-connect"
  compression   = "LZ4"
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "truenas_dataset" "onepassword_connect_data_legacy" {
  parent        = truenas_dataset.onepassword_connect_legacy.id
  path          = "data"
  compression   = "LZ4"
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "truenas_dataset" "onepassword_connect" {
  parent      = truenas_dataset.doco_cd.id
  path        = "1password-connect"
  compression = "LZ4"
  mode        = "0755"
  uid         = 999
  gid         = 999
}

resource "truenas_dataset" "onepassword_connect_data" {
  parent      = truenas_dataset.onepassword_connect.id
  path        = "data"
  compression = "LZ4"
  mode        = "0755"
  uid         = 999
  gid         = 999
}

resource "truenas_file" "onepassword_credentials" {
  path    = "/mnt/world/doco-cd/1password-connect/1password-credentials.json"
  content = var.onepassword_credentials_json
  mode    = "0600"
  uid     = 999
  gid     = 999

  depends_on = [truenas_dataset.onepassword_connect]
}

resource "truenas_file" "onepassword_token" {
  path    = "/mnt/world/doco-cd/1password-connect/connect-token"
  content = var.onepassword_connect_token
  mode    = "0600"
  uid     = 999
  gid     = 999

  depends_on = [truenas_dataset.onepassword_connect]
}

resource "truenas_file" "doco_cd_webhook_secret" {
  path    = "/mnt/world/doco-cd/webhook_secret"
  content = random_password.doco_cd_webhook_secret.result
  mode    = "0600"
  uid     = 1000
  gid     = 1000

  depends_on = [truenas_dataset.doco_cd]
}
