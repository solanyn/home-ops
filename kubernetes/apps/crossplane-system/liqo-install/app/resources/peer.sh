#!/bin/sh
set -e

export PATH="/shared:$PATH"

echo "Authenticating with GCP..."
gcloud auth activate-service-account --key-file=/etc/gcp/credentials.json

echo "Getting GKE cluster CA and endpoint..."
# Get cluster info
CLUSTER_CA=$(gcloud container clusters describe "${GKE_CLUSTER_NAME}" \
  --zone="${GCP_ZONE}" \
  --project="${GCP_PROJECT}" \
  --format='value(masterAuth.clusterCaCertificate)')

CLUSTER_ENDPOINT=$(gcloud container clusters describe "${GKE_CLUSTER_NAME}" \
  --zone="${GCP_ZONE}" \
  --project="${GCP_PROJECT}" \
  --format='value(endpoint)')

# Get access token
ACCESS_TOKEN=$(gcloud auth print-access-token)

# Create kubeconfig manually
cat > /shared/gke-kubeconfig << EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: ${CLUSTER_CA}
    server: https://${CLUSTER_ENDPOINT}
  name: gke-cluster
contexts:
- context:
    cluster: gke-cluster
    user: gke-user
  name: gke-context
current-context: gke-context
users:
- name: gke-user
  user:
    token: ${ACCESS_TOKEN}
EOF

echo "Testing GKE cluster access..."
export KUBECONFIG=/shared/gke-kubeconfig
if kubectl get nodes &> /dev/null; then
  echo "Successfully connected to GKE cluster"
else
  echo "Failed to connect to GKE cluster"
  exit 1
fi

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
cat > /shared/home-kubeconfig << EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: $(cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt | base64 -w0)
    server: https://kubernetes.default.svc
  name: home-cluster
contexts:
- context:
    cluster: home-cluster
    user: home-user
  name: home-context
current-context: home-context
users:
- name: home-user
  user:
    token: $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
EOF

# Check if peering already exists
export KUBECONFIG=/shared/home-kubeconfig
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
