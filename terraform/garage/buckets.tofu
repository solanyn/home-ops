resource "minio_s3_bucket" "bucket" {
  for_each = toset(var.buckets)
  bucket   = each.key
}
