#!/usr/bin/env bash
set -euo pipefail

: "${OPENCLAW_HOOKS_TOKEN:?}"
: "${GRAFANA_WEBHOOK_TOKEN:?}"

AUTH_TOKEN="${1:-}"
[[ "${AUTH_TOKEN}" != "Bearer ${GRAFANA_WEBHOOK_TOKEN}" ]] && exit 1

PAYLOAD=$(cat)

STATUS=$(echo "${PAYLOAD}" | jq -r '.status // "unknown"')
TITLE=$(echo "${PAYLOAD}" | jq -r '.title // "Grafana Alert"')
NUM_ALERTS=$(echo "${PAYLOAD}" | jq -r '.alerts | length // 0')
ALERT_DETAILS=$(echo "${PAYLOAD}" | jq -r '[.alerts[] | "\(.labels.alertname // "unnamed"): \(.annotations.summary // .annotations.description // "no details")"] | join("; ")' 2>/dev/null || echo "no details")

if [[ "${STATUS}" == "resolved" ]]; then
    MESSAGE="Grafana alert resolved: ${TITLE}. ${ALERT_DETAILS}."
else
    MESSAGE="Grafana alert ${STATUS}: ${TITLE} (${NUM_ALERTS} firing). ${ALERT_DETAILS}. Triage: check relevant pods/logs. Report findings."
fi

curl -sf -X POST http://openclaw.ai.svc.cluster.local:18789/hooks/agent \
    -H "Authorization: Bearer ${OPENCLAW_HOOKS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg msg "${MESSAGE}" '{message: $msg, name: "Grafana Alert"}')"
