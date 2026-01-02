#!/bin/bash
# Import existing garage buckets into terraform state
# Run this script once to import existing buckets

terraform import 'garage_bucket.bucket["open-webui"]' f383113e64af5443
terraform import 'garage_bucket.bucket["mlflow"]' 8b7d4c74fb8d75e1
terraform import 'garage_bucket.bucket["label-studio"]' 52c8dcc9e81e4438
terraform import 'garage_bucket.bucket["cloudnative-pg"]' 061c75762c080ebb
terraform import 'garage_bucket.bucket["pxc"]' ad929723a5582458
terraform import 'garage_bucket.bucket["kubeflow"]' f12fe90c8717fff7
terraform import 'garage_bucket.bucket["trino"]' 9e9b557981a5a249
terraform import 'garage_bucket.bucket["kfp-pipelines"]' a0201dcc49e97438
terraform import 'garage_bucket.bucket["dragonflydb"]' f98bcdcc45de4087
terraform import 'garage_bucket.bucket["mariadb"]' 763797b285d2372b
terraform import 'garage_bucket.bucket["ferretdb"]' 5bd077e98671c4b0
