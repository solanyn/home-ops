import {
  for_each = toset(var.buckets)
  to       = garage_bucket.bucket[each.key]
  id       = each.key
}

resource "garage_bucket" "bucket" {
  for_each     = toset(var.buckets)
  global_alias = each.key
}
