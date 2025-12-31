terraform {
  required_providers {
    minio = {
      source  = "aminueza/minio"
      version = ">= 3.0.0"
    }
  }
}

provider "minio" {
  minio_server   = "garage.storage.svc.cluster.local:3900"
  minio_user     = var.garage_root_user
  minio_password = var.garage_root_password
  minio_ssl      = false
}
