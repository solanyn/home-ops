#!/usr/bin/env bash
# SSH to the edge VPS without recipe-level quoting hazards.
# Connection details come from the environment so recipes stay one-liners.
#
#   EDGE_HOST  (required)  EDGE_USER (default ubuntu)
#   EDGE_PORT  (default 22222)  EDGE_KEY (default ~/.ssh/edge_ssh)
#
# Usage: ssh-edge.sh <remote-command...>
set -euo pipefail

host="${EDGE_HOST:?EDGE_HOST is required}"
user="${EDGE_USER:-ubuntu}"
port="${EDGE_PORT:-22222}"
key="${EDGE_KEY:-$HOME/.ssh/edge_ssh}"

exec ssh -p "$port" -i "$key" -o IdentitiesOnly=yes "$user@$host" "$@"
