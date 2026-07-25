#!/usr/bin/env bash
set -euo pipefail

# op expects its config directory to have restricted permissions (700).
# The PVC may have been created with broader perms; ensure safety here.
OP_CONFIG="${OP_CONFIG_DIR:-/opt/data/.config/op}"
mkdir -p "$OP_CONFIG"
chmod 700 "$OP_CONFIG"
if [ -f "$OP_CONFIG/config" ]; then
    chmod 600 "$OP_CONFIG/config"
fi

if ! command -v kubectl >/dev/null 2>&1; then
    echo "[hermes-entrypoint] WARN: kubectl not on PATH"
fi
if ! command -v flux >/dev/null 2>&1; then
    echo "[hermes-entrypoint] WARN: flux not on PATH"
fi
if ! command -v bat >/dev/null 2>&1; then
    echo "[hermes-entrypoint] WARN: bat not on PATH"
fi
if ! command -v shellcheck >/dev/null 2>&1; then
    echo "[hermes-entrypoint] WARN: shellcheck not on PATH"
fi
if ! command -v op >/dev/null 2>&1; then
    echo "[hermes-entrypoint] WARN: op not on PATH"
fi
if ! command -v gh >/dev/null 2>&1; then
    echo "[hermes-entrypoint] WARN: gh not on PATH"
fi
if ! command -v tofu >/dev/null 2>&1; then
    echo "[hermes-entrypoint] WARN: tofu not on PATH"
fi
if ! command -v jq >/dev/null 2>&1; then
    echo "[hermes-entrypoint] WARN: jq not on PATH"
fi
if ! command -v yq >/dev/null 2>&1; then
    echo "[hermes-entrypoint] WARN: yq not on PATH"
fi
if ! command -v sops >/dev/null 2>&1; then
    echo "[hermes-entrypoint] WARN: sops not on PATH"
fi

exec /opt/hermes/bin/hermes "$@"