#!/usr/bin/env bash
set -euo pipefail

: "${OPENCLAW_HOOKS_TOKEN:?OpenClaw hooks token required}"

# Flux generic-hmac Provider sends JSON body directly
# Read payload from stdin
PAYLOAD=$(cat)

SEVERITY=$(echo "${PAYLOAD}" | jq -r '.severity // "info"')
REASON=$(echo "${PAYLOAD}" | jq -r '.reason // "unknown"')
MSG=$(echo "${PAYLOAD}" | jq -r '.message // "no message"')
INVOLVED=$(echo "${PAYLOAD}" | jq -r '.involvedObject.name // "unknown"')
NAMESPACE=$(echo "${PAYLOAD}" | jq -r '.involvedObject.namespace // "unknown"')
KIND=$(echo "${PAYLOAD}" | jq -r '.involvedObject.kind // "unknown"')

echo "[INFO] Flux ${SEVERITY}: ${KIND}/${NAMESPACE}/${INVOLVED} — ${REASON}: ${MSG}"

# Only alert on errors/warnings, not info
if [[ "${SEVERITY}" == "info" ]]; then
    echo "[INFO] Skipping info-level alert"
    exit 0
fi

MESSAGE="Flux ${SEVERITY}: ${KIND} ${INVOLVED} in ${NAMESPACE} — ${REASON}. ${MSG}. Check with: ssh mac.internal \"KUBECONFIG=~/git/home-ops/kubeconfig kubectl describe ${KIND,,} ${INVOLVED} -n ${NAMESPACE}\". Report to Andrew on Matrix."

curl -sf -X POST http://openclaw.ai.svc.cluster.local:18789/hooks/agent \
    -H "Authorization: Bearer ${OPENCLAW_HOOKS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg msg "${MESSAGE}" '{message: $msg, name: "Flux Alert"}')"

echo "[INFO] Notified OpenClaw"
