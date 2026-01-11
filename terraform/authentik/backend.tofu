terraform {
  backend "s3" {
    bucket = "terraform-state"
    key    = "authentik/authentik.tfstate"
    region = "us-east-1"

    endpoints = {
      s3 = "http://garage.storage.svc.cluster.local:3900"
    }

    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    use_path_style              = true
  }
}
