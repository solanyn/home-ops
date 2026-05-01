#!/usr/bin/env bash
set -euo pipefail

: "${OPENCLAW_HOOKS_TOKEN:?}"
API_URL="${OPENCODE_API_URL:-http://mac.internal:4096}"
STATE_DIR="/tmp/opencode-webhook"

PAYLOAD=$(cat)

EVENT_TYPE=$(echo "${PAYLOAD}" | jq -r '.event.type // ""')
[[ "${EVENT_TYPE}" != "message.updated" ]] && exit 0

ROLE=$(echo "${PAYLOAD}" | jq -r '.event.properties.info.role // ""')
[[ "${ROLE}" != "assistant" ]] && exit 0

COMPLETED=$(echo "${PAYLOAD}" | jq -r '.event.properties.info.time.completed // ""')
[[ -z "${COMPLETED}" || "${COMPLETED}" == "null" ]] && exit 0

MSG_ID=$(echo "${PAYLOAD}" | jq -r '.event.properties.info.id // ""')
SESSION_ID=$(echo "${PAYLOAD}" | jq -r '.event.properties.info.sessionID // ""')
[[ -z "${MSG_ID}" || -z "${SESSION_ID}" ]] && exit 0

mkdir -p "${STATE_DIR}"
find "${STATE_DIR}" -type f -mmin +10 -delete 2>/dev/null || true
[[ -e "${STATE_DIR}/${MSG_ID}" ]] && exit 0
touch "${STATE_DIR}/${MSG_ID}"

SESSION_JSON=$(curl -sf "${API_URL}/session/${SESSION_ID}" || echo '{}')
TITLE=$(echo "${SESSION_JSON}" | jq -r '.title // ""')
[[ ! "${TITLE}" =~ ^HAWOW: ]] && exit 0

MESSAGE="OpenCode session ${TITLE} finished (sessionID: ${SESSION_ID}). Read the last assistant message and continue."

curl -sf -X POST http://openclaw.ai.svc.cluster.local:18789/hooks/agent \
    -H "Authorization: Bearer ${OPENCLAW_HOOKS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg msg "${MESSAGE}" '{message: $msg, name: "OpenCode"}')"
