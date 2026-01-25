#!/bin/sh
set -e

# Setup Nix environment
if [ -f /root/.nix-profile/etc/profile.d/nix.sh ]; then
    . /root/.nix-profile/etc/profile.d/nix.sh
elif [ -f /nix/var/nix/profiles/default/etc/profile.d/nix.sh ]; then
    . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
fi

# Install devenv if not present in profile
if ! command -v devenv >/dev/null 2>&1; then
  echo "Installing devenv..."
  nix profile install --accept-flake-config github:cachix/devenv/latest
fi

# Prepare writable workspace
mkdir -p /workspace/sandbox
cp /app/config/devenv.nix /workspace/sandbox/devenv.nix
cp /app/config/devenv.yaml /workspace/sandbox/devenv.yaml
cp /app/config/AGENTS.md /workspace/sandbox/AGENTS.md

cd /workspace/sandbox

# Trust the flake
nix flake lock --accept-flake-config

# Execute devenv processes
echo "Starting processes via devenv..."
exec devenv up
