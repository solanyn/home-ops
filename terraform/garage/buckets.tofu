import {
  to = garage_bucket.bucket["open-webui"]
  id = "f383113e64af5443"
}

import {
  to = garage_bucket.bucket["mlflow"]
  id = "8b7d4c74fb8d75e1"
}

import {
  to = garage_bucket.bucket["label-studio"]
  id = "52c8dcc9e81e4438"
}

import {
  to = garage_bucket.bucket["cloudnative-pg"]
  id = "061c75762c080ebb"
}

import {
  to = garage_bucket.bucket["pxc"]
  id = "ad929723a5582458"
}

import {
  to = garage_bucket.bucket["kubeflow"]
  id = "f12fe90c8717fff7"
}

import {
  to = garage_bucket.bucket["trino"]
  id = "9e9b557981a5a249"
}

import {
  to = garage_bucket.bucket["kfp-pipelines"]
  id = "a0201dcc49e97438"
}

import {
  to = garage_bucket.bucket["dragonflydb"]
  id = "f98bcdcc45de4087"
}

import {
  to = garage_bucket.bucket["mariadb"]
  id = "763797b285d2372b"
}

import {
  to = garage_bucket.bucket["ferretdb"]
  id = "5bd077e98671c4b0"
}

import {
  to = garage_bucket.bucket["terraform-state"]
  id = "67f971eb711750ed"
}

resource "garage_bucket" "bucket" {
  for_each     = toset(var.buckets)
  global_alias = each.key
}
