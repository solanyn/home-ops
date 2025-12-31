locals {
  buckets = [
    "gitlab",
    "label-studio",
    "tempo-traces",
    "mariadb",
    "kfp-pipelines",
    "mlflow",
    "cloudnative-pg",
    "dragonflydb",
    "kubeflow",
    "trino"
  ]
}

resource "minio_s3_bucket" "buckets" {
  for_each = toset(local.buckets)
  bucket   = each.key
}
