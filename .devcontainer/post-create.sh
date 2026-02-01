#!/bin/bash
set -e

echo "Setting up home-ops dev environment..."

# Install system dependencies
apt-get update && apt-get install -y \
  build-essential \
  curl \
  wget \
  unzip \
  jq \
  yq \
  ca-certificates \
  gnupg \
  lsb-release \
  apt-transport-https \
  software-properties-common

# Install Go (for home-ops development)
if ! command -v go &> /dev/null; then
  GO_VERSION="1.23"
  curl -sL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -o /tmp/go.tar.gz
  tar -C /usr/local -xzf /tmp/go.tar.gz
  echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
  export PATH=$PATH:/usr/local/go/bin
fi

# Install k9s (Kubernetes dashboard)
if ! command -v k9s &> /dev/null; then
  curl -sS https://webinstall.dev/k9s | bash
fi

# Install kustomize
if ! command -v kustomize &> /dev/null; then
  curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
  mv kustomize /usr/local/bin/
fi

# Install Flux CLI
if ! command -v flux &> /dev/null; then
  curl -s https://fluxcd.io/install.sh | bash
fi

# Install Talos CLI
if ! command -v talosctl &> /dev/null; then
  curl -sL https://github.com/siderolabs/talos/releases/latest/download/talosctl-linux-amd64 -o /usr/local/bin/talosctl
  chmod +x /usr/local/bin/talosctl
fi

# Install helm-diff plugin
helm plugin install https://github.com/databus23/helm-diff || true

# Install helm-secrets plugin
helm plugin install https://github.com/jkroepke/helm-secrets || true

# Setup shell completion
kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
helm completion bash | sudo tee /etc/bash_completion.d/helm > /dev/null

echo "Dev environment setup complete!"
echo ""
echo "Available tools:"
echo "  - kubectl, helm, kustomize: Kubernetes management"
echo "  - k9s: Kubernetes TUI dashboard"
echo "  - flux: GitOps management"
echo "  - talosctl: Talos OS management"
echo "  - docker: Container management"
echo "  - go: Go development"
echo "  - git, gh: Version control"
