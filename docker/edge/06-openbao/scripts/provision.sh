#!/usr/bin/env bash
# Create /opt/openbao/data on the VPS owned by the image's unprivileged uid/gid.
# Refuses if Raft data already exists, so it can never re-permission live data.
#
# Usage: provision.sh <edge-ssh-command>
set -euo pipefail

edge_ssh="${1:?usage: provision.sh <ssh-cmd>}"

if $edge_ssh 'sudo test -e /opt/openbao/data/raft/vault.db'; then
  echo "REFUSING: Raft data already exists at /opt/openbao/data" >&2
  exit 1
fi

$edge_ssh 'sudo mkdir -p /opt/openbao/data'
$edge_ssh 'sudo chown 100:1000 /opt/openbao/data'
$edge_ssh 'sudo chmod 750 /opt/openbao/data'
$edge_ssh 'sudo ls -lnd /opt/openbao/data'
echo "OK: /opt/openbao/data ready (uid 100 / gid 1000, mode 750)"
