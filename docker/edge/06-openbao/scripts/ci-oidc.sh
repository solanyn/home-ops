#!/usr/bin/env bash
# Configure GitHub Actions OIDC access to OpenBao. Idempotent.
#
# Creates a dedicated JWT auth mount that trusts GitHub's OIDC issuer, a
# read-only policy for the paths CI needs, and a role bound to this repository.
# The existing jwt mount stays untouched: it validates the cluster's
# service-account JWKS for External Secrets.
set -euo pipefail

BAO_ADDR="${BAO_ADDR:-https://bao.goyangi.io}"
REPO="${GITHUB_REPOSITORY_OWNER:-solanyn}/${GITHUB_REPOSITORY_NAME:-home-ops}"
AUDIENCE="${CI_AUDIENCE:-https://github.com/${REPO%%/*}}"
MOUNT="${CI_JWT_MOUNT:-jwt-github}"
ROLE="${CI_ROLE:-home-ops-ci}"
POLICY="${CI_POLICY:-ci-read}"

if [[ -z "${BAO_TOKEN:-}" ]]; then
    BAO_TOKEN="$(op read 'op://kubernetes/openbao/OPENBAO_ROOT_TOKEN')"
fi
export BAO_TOKEN

api() {
    local method="$1" path="$2" body="${3:-}"
    if [[ -n "$body" ]]; then
        curl -fsS -X "$method" -H "X-Vault-Token: $BAO_TOKEN" \
            -H 'Content-Type: application/json' -d "$body" "$BAO_ADDR/v1/$path"
    else
        curl -fsS -X "$method" -H "X-Vault-Token: $BAO_TOKEN" "$BAO_ADDR/v1/$path"
    fi
}

# Mount and discovery URL.
if ! api GET "sys/auth" | jq -e --arg m "$MOUNT/" '.data[$m]' >/dev/null; then
    api POST "sys/auth/$MOUNT" "{\"type\":\"jwt\",\"description\":\"GitHub Actions OIDC\"}" >/dev/null
    echo "enabled auth mount $MOUNT"
fi
api POST "auth/$MOUNT/config" \
    '{"oidc_discovery_url":"https://token.actions.githubusercontent.com"}' >/dev/null
echo "configured $MOUNT to trust GitHub OIDC"

# Least-privilege read policy: only the items CI consumes.
policy=$(cat <<HCL
path "kv/data/unifi"         { capabilities = ["read"] }
path "kv/metadata/unifi"     { capabilities = ["read"] }
path "kv/data/ocharted"      { capabilities = ["read"] }
path "kv/metadata/ocharted"  { capabilities = ["read"] }
HCL
)
api PUT "sys/policies/acl/$POLICY" "$(jq -n --arg p "$policy" '{policy:$p}')" >/dev/null
echo "wrote policy $POLICY"

# Role bound to this repository only.
role=$(jq -n --arg aud "$AUDIENCE" --arg repo "$REPO" --arg pol "$POLICY" \
    '{role_type:"jwt",user_claim:"sub",bound_audiences:[$aud],
      bound_claims:{repository:$repo},token_policies:[$pol],
      token_ttl:900,token_max_ttl:1800}')
api POST "auth/$MOUNT/role/$ROLE" "$role" >/dev/null
echo "wrote role $ROLE for $REPO at audience $AUDIENCE"
