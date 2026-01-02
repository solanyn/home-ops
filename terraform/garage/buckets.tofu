resource "garage_bucket" "bucket" {
  for_each     = toset(var.buckets)
  global_alias = each.key
}
