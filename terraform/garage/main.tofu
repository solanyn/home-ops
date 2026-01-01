terraform {
  required_providers {
    minio = {
      source  = "aminueza/minio"
      version = "3.12.0"
    }
  }
}

provider "minio" {
  minio_server   = var.GARAGE_URL
  minio_user     = var.AWS_ACCESS_KEY_ID
  minio_password = var.AWS_SECRET_ACCESS_KEY
  minio_ssl      = false
}
