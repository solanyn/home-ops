terraform {
  required_providers {
    garage = {
      source  = "schwitzd/garage"
      version = "1.2.2"
    }
  }
}

provider "garage" {
  host       = "http://${var.GARAGE_URL}"
  access_key = var.AWS_ACCESS_KEY_ID
  secret_key = var.AWS_SECRET_ACCESS_KEY
}
