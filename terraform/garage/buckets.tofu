import {
  for_each = toset(var.buckets)
  to       = minio_s3_bucket.bucket[each.key]
  id       = each.key
}

resource "minio_s3_bucket" "bucket" {
  for_each = toset(var.buckets)
  bucket   = each.key
}
