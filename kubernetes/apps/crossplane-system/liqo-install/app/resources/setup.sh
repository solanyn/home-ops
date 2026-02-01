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

echo "Tools downloaded successfully"
