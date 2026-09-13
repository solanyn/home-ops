terraform {
  required_version = ">= 1.5.0"

  required_providers {
    truenas = {
      source  = "deevus/truenas"
      version = "~> 0.16"
    }
  }
}
