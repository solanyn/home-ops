#!/usr/bin/env bash
# Initialize OpenBao exactly once, refusing to run if it already is.
# Writes the init response to a 0600 file for transfer into 1Password.
#
# Usage: init.sh <edge-ssh-command> <output-path> <validate.py-path>
set -euo pipefail

edge_ssh="${1:?usage: init.sh <ssh-cmd> <out> <validate.py>}"
out="${2:?}"
validator="${3:?}"

if [ -e "$out" ]; then
  echo "REFUSING: $out exists; store it in 1Password and delete it first" >&2
  exit 1
fi

status_json="$($edge_ssh 'sudo docker exec openbao bao status -format=json' 2>/dev/null || true)"
printf '%s' "$status_json" | python3 "$validator" status

umask 077
$edge_ssh 'sudo docker exec openbao bao operator init -recovery-shares=1 -recovery-threshold=1 -format=json' > "$out"
chmod 600 "$out"

python3 "$validator" init "$out"
echo "Wrote $out (mode 0600)."
echo "Store it in 1Password item 'openbao' as OPENBAO_RECOVERY_KEY and OPENBAO_ROOT_TOKEN, then delete the file."
