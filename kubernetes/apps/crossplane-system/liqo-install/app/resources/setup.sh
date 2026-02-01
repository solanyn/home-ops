#!/bin/sh
set -e

echo "Downloading kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /shared/

echo "Downloading liqoctl..."
curl -LO https://github.com/liqotech/liqo/releases/download/v0.10.3/liqoctl-linux-amd64
chmod +x liqoctl-linux-amd64
mv liqoctl-linux-amd64 /shared/liqoctl

echo "Downloading gke-gcloud-auth-plugin..."
curl -LO https://storage.googleapis.com/cloud-sdk-release/gke-gcloud-auth-plugin-linux-amd64.tar.gz
tar -xzf gke-gcloud-auth-plugin-linux-amd64.tar.gz
mv gke-gcloud-auth-plugin /shared/
chmod +x /shared/gke-gcloud-auth-plugin
rm gke-gcloud-auth-plugin-linux-amd64.tar.gz

echo "Tools downloaded successfully"
