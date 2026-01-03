resource "garage_bucket" "bucket" {
  for_each     = toset(var.buckets)
  global_alias = each.key
}

resource "garage_bucket_key" "root_access" {
  for_each      = garage_bucket.bucket
  bucket_id     = each.value.id
  access_key_id = var.GARAGE_ROOT_ACCESS_KEY_ID
  read          = true
  write         = true
  owner         = true
}
