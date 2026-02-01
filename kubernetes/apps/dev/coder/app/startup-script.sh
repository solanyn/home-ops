#!/bin/bash
set -e

echo "Coder workspace startup script running..."

# Update system packages
apt-get update && apt-get install -y \
  curl \
  wget \
  git \
  build-essential \
  ca-certificates

# Install Docker CLI (for buildkit access)
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
rm get-docker.sh

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install VS Code Server
if ! command -v code-server &> /dev/null; then
  curl -fsSL https://code-server.dev/install.sh | bash
fi

# Install ttyd for web terminal access
if ! command -v ttyd &> /dev/null; then
  curl -fsSL https://github.com/tsl0923/ttyd/releases/download/1.6.3/ttyd.x86_64 -o /usr/local/bin/ttyd
  chmod +x /usr/local/bin/ttyd
fi

# Start code-server in the background
code-server --bind-addr 0.0.0.0:8000 --auth none &

# Start ttyd for terminal access
ttyd -p 7681 bash &

# Run devcontainer.json initialization if it exists in the mounted repo
if [ -f "/home/.devcontainer/post-create.sh" ]; then
  echo "Running devcontainer post-create script..."
  bash /home/.devcontainer/post-create.sh
fi

# Keep the container running
tail -f /dev/null
