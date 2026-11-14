#!/usr/bin/env bash
# Copy files to the edge VPS. Connection details come from the environment.
#
# Usage: scp-edge.sh <local> <remote-path>
set -euo pipefail

host="${EDGE_HOST:?EDGE_HOST is required}"
user="${EDGE_USER:-ubuntu}"
port="${EDGE_PORT:-22222}"
key="${EDGE_KEY:-$HOME/.ssh/edge_ssh}"

exec scp -P "$port" -i "$key" -o IdentitiesOnly=yes "$1" "$user@$host:$2"
