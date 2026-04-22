#!/usr/bin/env bash
set -euo pipefail

: "${OPENCLAW_HOOKS_TOKEN:?}"

PAYLOAD=$(cat)

STATUS=$(echo "${PAYLOAD}" | jq -r '.status // "unknown"')
NUM_ALERTS=$(echo "${PAYLOAD}" | jq -r '.alerts | length // 0')
ALERT_DETAILS=$(echo "${PAYLOAD}" | jq -r '[.alerts[] | "\(.labels.alertname) [\(.labels.severity // "unknown")]: \(.annotations.description // .annotations.summary // .annotations.message // "no details") (namespace: \(.labels.namespace // "n/a"))"] | join("; ")' 2>/dev/null || echo "no details")
COMMON_LABELS=$(echo "${PAYLOAD}" | jq -r '.commonLabels.alertname // "unknown"')

MESSAGE="Alertmanager ${STATUS}: ${COMMON_LABELS} (${NUM_ALERTS} alerts). ${ALERT_DETAILS}. TRANSIENT CHECK: wait 60s then verify alert still firing via kubectl. If resolved, skip. If still firing, triage and report."

curl -sf -X POST http://openclaw.ai.svc.cluster.local:18789/hooks/agent \
    -H "Authorization: Bearer ${OPENCLAW_HOOKS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg msg "${MESSAGE}" '{message: $msg, name: "Alertmanager"}')"
