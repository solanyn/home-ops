#!/usr/bin/env bash
set -euo pipefail

: "${OPENCLAW_HOOKS_TOKEN:?OpenClaw hooks token required}"
: "${GRAFANA_WEBHOOK_TOKEN:?Grafana webhook token required}"

# Validate token from Authorization header (passed as arg)
AUTH_TOKEN="${1:-}"
if [[ "${AUTH_TOKEN}" != "Bearer ${GRAFANA_WEBHOOK_TOKEN}" ]]; then
    echo "[WARN] Invalid auth token"
    exit 1
fi

# Grafana webhook sends JSON body via stdin
PAYLOAD=$(cat)

STATUS=$(echo "${PAYLOAD}" | jq -r '.status // "unknown"')
TITLE=$(echo "${PAYLOAD}" | jq -r '.title // "Grafana Alert"')
STATE=$(echo "${PAYLOAD}" | jq -r '.state // "unknown"')
NUM_ALERTS=$(echo "${PAYLOAD}" | jq -r '.alerts | length // 0')

# Extract alert summaries
ALERT_DETAILS=$(echo "${PAYLOAD}" | jq -r '[.alerts[] | "\(.labels.alertname // "unnamed"): \(.annotations.summary // .annotations.description // "no details")"] | join("; ")' 2>/dev/null || echo "no details")

echo "[INFO] Grafana ${STATUS}: ${TITLE} (${NUM_ALERTS} alerts)"

# Skip resolved unless it was previously firing
if [[ "${STATUS}" == "resolved" ]]; then
    MESSAGE="Grafana alert resolved: ${TITLE}. ${ALERT_DETAILS}."
else
    MESSAGE="Grafana alert ${STATUS}: ${TITLE} (${NUM_ALERTS} firing). ${ALERT_DETAILS}. Triage: check relevant pods/logs via ssh mac.internal kubectl. Report to Andrew on Matrix."
fi

curl -sf -X POST http://openclaw.ai.svc.cluster.local:18789/hooks/agent \
    -H "Authorization: Bearer ${OPENCLAW_HOOKS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg msg "${MESSAGE}" '{message: $msg, name: "Grafana Alert"}')"

echo "[INFO] Notified OpenClaw"
