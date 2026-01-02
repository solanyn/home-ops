terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2025.10.1"
    }
    onepassword = {
      source  = "1password/onepassword"
      version = "3.0.1"
    }
  }
}

provider "onepassword" {
  connect_url   = var.OP_CONNECT_HOST
  connect_token = var.OP_CONNECT_TOKEN
}

data "onepassword_item" "authentik" {
  vault = "kubernetes"
  title = "authentik"
}

provider "authentik" {
  url   = "https://id.${var.CLUSTER_DOMAIN}"
  token = data.onepassword_item.authentik.password
}
