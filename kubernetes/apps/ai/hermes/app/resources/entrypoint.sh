#!/usr/bin/env bash
set -euo pipefail

# Best-effort: install CLI tools the agent may shell out to.
# Zerobrew packages land in $ZEROBREW_PREFIX/bin (default $HOME/.local/share/zerobrew/prefix/bin).
# The init container pre-creates /opt/data/homebrew/bin for zb, and the helmrelease
# sets ZEROBREW_PREFIX=/opt/data/homebrew so binaries land there directly.
for tool in kubectl flux bat shellcheck; do
    if [[ ! -x "/opt/data/homebrew/bin/$tool" ]]; then
        echo "[hermes-entrypoint] Installing $tool..."
        zb install "$tool" >/dev/null 2>&1 || echo "[hermes-entrypoint] Failed to install $tool"
    fi
done

exec /opt/hermes/bin/hermes "$@"
