terraform {
    required_version = ">= 1.5.0"
    required_providers {
        unifi = {
            source  = "ubiquiti-community/unifi"
            version = "~> 0.55"
        }
    }
}