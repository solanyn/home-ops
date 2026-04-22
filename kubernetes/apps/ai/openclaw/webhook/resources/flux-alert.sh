#!/usr/bin/env bash
set -euo pipefail

: "${OPENCLAW_HOOKS_TOKEN:?}"

PAYLOAD=$(cat)

SEVERITY=$(echo "${PAYLOAD}" | jq -r '.severity // "info"')
REASON=$(echo "${PAYLOAD}" | jq -r '.reason // "unknown"')
MSG=$(echo "${PAYLOAD}" | jq -r '.message // "no message"')
INVOLVED=$(echo "${PAYLOAD}" | jq -r '.involvedObject.name // "unknown"')
NAMESPACE=$(echo "${PAYLOAD}" | jq -r '.involvedObject.namespace // "unknown"')
KIND=$(echo "${PAYLOAD}" | jq -r '.involvedObject.kind // "unknown"')

[[ "${SEVERITY}" == "info" ]] && exit 0

MESSAGE="Flux ${SEVERITY}: ${KIND} ${INVOLVED} in ${NAMESPACE} — ${REASON}. ${MSG}. Triage: check pod events, logs, image digests. Report findings."

curl -sf -X POST http://openclaw.ai.svc.cluster.local:18789/hooks/agent \
    -H "Authorization: Bearer ${OPENCLAW_HOOKS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg msg "${MESSAGE}" '{message: $msg, name: "Flux Alert"}')"
