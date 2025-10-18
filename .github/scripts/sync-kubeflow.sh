#!/usr/bin/env bash
set -euo pipefail

# Script to sync Kubeflow manifests from upstream
# Called by Renovate's postUpgradeTasks
# Usage: sync-kubeflow.sh <version>

VERSION="${1:-}"

if [[ -z "$VERSION" ]]; then
  echo "❌ Error: Version argument required"
  echo "Usage: $0 <version>"
  exit 1
fi

echo "🔄 Syncing Kubeflow manifests from version: $VERSION"

DEST_BASE="third_party/kubeflow/manifests"
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Clone upstream at specified version
echo "📥 Cloning kubeflow/manifests@$VERSION..."
git clone --depth 1 --branch "$VERSION" https://github.com/kubeflow/manifests.git "$TEMP_DIR/manifests"

# Folders to sync
FOLDERS=(common apps experimental example)

for folder in "${FOLDERS[@]}"; do
  src="$TEMP_DIR/manifests/${folder}"
  dest="${DEST_BASE}/${folder}"

  if [[ ! -d "$src" ]]; then
    echo "⚠️  Source folder '$src' not found. Skipping."
    continue
  fi

  echo "🔁 Syncing ${folder}..."
  
  # Remove OWNERS files
  find "$src" -name "OWNERS" -type f -delete
  
  # Create destination directory if it doesn't exist
  mkdir -p "$dest"
  
  # Sync folder
  rm -rf "${dest:?}"/*
  cp -r "$src/"* "$dest/"
  
  echo "✅ Synced ${folder}"
done

echo "✨ Kubeflow manifests sync complete!"
