#!/usr/bin/env bash
# Read the static seal key from 1Password and verify its shape.
# Never prints the value.
set -euo pipefail

seal_ref="${1:?usage: check-secrets.sh <op-reference>}"
token_file="${OP_TOKEN_FILE:-$HOME/.op-token}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

OP_SERVICE_ACCOUNT_TOKEN="$(<"$token_file")" \
  op read --force --out-file "$tmp/seal" "$seal_ref" >/dev/null

python3 "$(dirname "$0")/check-seal-key.py" "$tmp/seal"
echo "OK: $seal_ref is readable"
