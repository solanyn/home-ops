#!/usr/bin/env bash
# Verify a TLS cert+key pair match by comparing their public-key SHA256 hashes.
# Exit 0 = match, exit 1 = mismatch.
#
# Usage: verify-tls-pair.sh <cert.pem> <key.pem>

set -euo pipefail

CERT="${1:?usage: verify-tls-pair.sh <cert.pem> <key.pem>}"
KEY="${2:?usage: verify-tls-pair.sh <cert.pem> <key.pem>}"

[ -f "$CERT" ] || { echo "cert not found: $CERT" >&2; exit 2; }
[ -f "$KEY" ]  || { echo "key not found: $KEY"  >&2; exit 2; }

CERT_HASH=$(openssl x509 -in "$CERT" -noout -pubkey 2>/dev/null \
  | openssl pkey -pubin -outform DER 2>/dev/null \
  | sha256sum | cut -d' ' -f1)

KEY_HASH=$(openssl rsa -in "$KEY" -pubout 2>/dev/null \
  | openssl pkey -pubin -outform DER 2>/dev/null \
  | sha256sum | cut -d' ' -f1)

if [ "$CERT_HASH" = "$KEY_HASH" ]; then
  echo "✓ match"
  exit 0
else
  echo "✗ MISMATCH"
  echo "  cert pubkey: $CERT_HASH"
  echo "  key  pubkey: $KEY_HASH"
  exit 1
fi
