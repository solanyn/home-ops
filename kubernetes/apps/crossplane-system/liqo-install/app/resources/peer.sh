#!/bin/sh
set -e

export PATH="/shared:$PATH"

echo "Installing gke-gcloud-auth-plugin..."
apt-get update && apt-get install -y google-cloud-cli-gke-gcloud-auth-plugin

echo "Authenticating with GCP..."
gcloud auth activate-service-account --key-file=/etc/gcp/credentials.json

echo "Getting GKE cluster credentials..."
gcloud container clusters get-credentials "${GKE_CLUSTER_NAME}" \
  --zone="${GCP_ZONE}" \
  --project="${GCP_PROJECT}"

# Save GKE kubeconfig for later use
cp ~/.kube/config /shared/gke-kubeconfig

# Check if Liqo is already installed
if kubectl get namespace liqo-system &> /dev/null; then
  echo "Liqo namespace already exists, skipping installation..."
else
  echo "Installing Liqo on GKE cluster..."
  liqoctl install \
    --cluster-name="${CLUSTER_NAME}" \
    --service-type=LoadBalancer

  echo "Waiting for Liqo to be ready on GKE cluster..."
  kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=liqo \
    -n liqo-system \
    --timeout=300s

  echo "Liqo installed successfully on GKE cluster!"
fi

echo "Setting up peering with home cluster..."

# Create kubeconfig for home cluster using service account token
export KUBECONFIG=/shared/home-kubeconfig
kubectl config set-cluster home-cluster \
  --server="https://kubernetes.default.svc" \
  --certificate-authority=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
kubectl config set-credentials home-user --token="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
kubectl config set-context home-context --cluster=home-cluster --user=home-user
kubectl config use-context home-context

# Check if peering already exists
if kubectl get foreignclusters.liqo.io "${CLUSTER_NAME}" &> /dev/null; then
  echo "Peering with ${CLUSTER_NAME} already exists, skipping..."
else
  echo "Peering clusters..."
  liqoctl peer \
    --kubeconfig=/shared/home-kubeconfig \
    --remote-kubeconfig=/shared/gke-kubeconfig

  echo "Peering completed successfully!"
fi

echo "Liqo setup complete!"
