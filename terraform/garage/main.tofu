terraform {
  required_providers {
    garage = {
      source  = "schwitzd/garage"
      version = "1.2.2"
    }
  }
}

provider "garage" {
  host  = var.GARAGE_ADMIN_URL
  token = var.GARAGE_ADMIN_TOKEN
}
