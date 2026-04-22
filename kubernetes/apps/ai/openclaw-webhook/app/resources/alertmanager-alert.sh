#!/usr/bin/env bash
set -euo pipefail

: "${OPENCLAW_HOOKS_TOKEN:?OpenClaw hooks token required}"

# Alertmanager webhook receiver format
PAYLOAD=$(cat)

STATUS=$(echo "${PAYLOAD}" | jq -r '.status // "unknown"')
NUM_ALERTS=$(echo "${PAYLOAD}" | jq -r '.alerts | length // 0')

# Build summary from alerts
ALERT_DETAILS=$(echo "${PAYLOAD}" | jq -r '[.alerts[] | "\(.labels.alertname) [\(.labels.severity // "unknown")]: \(.annotations.description // .annotations.summary // .annotations.message // "no details") (namespace: \(.labels.namespace // "n/a"))"] | join("; ")' 2>/dev/null || echo "no details")

COMMON_LABELS=$(echo "${PAYLOAD}" | jq -r '.commonLabels.alertname // "unknown"')

echo "[INFO] Alertmanager ${STATUS}: ${COMMON_LABELS} (${NUM_ALERTS} alerts)"

MESSAGE="Alertmanager ${STATUS}: ${COMMON_LABELS} (${NUM_ALERTS} alerts). ${ALERT_DETAILS}. TRANSIENT CHECK: wait 60s then verify alert still firing via: ssh mac.internal \"KUBECONFIG=~/git/home-ops/kubeconfig kubectl exec -n observability alertmanager-kube-prometheus-stack-0 -- wget -qO- http://localhost:9093/api/v2/alerts?filter=alertname%3D${COMMON_LABELS}\". If resolved, log and skip. If still firing, triage with kubectl and report to Andrew on Matrix."

curl -sf -X POST http://openclaw.ai.svc.cluster.local:18789/hooks/agent \
    -H "Authorization: Bearer ${OPENCLAW_HOOKS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg msg "${MESSAGE}" '{message: $msg, name: "Alertmanager"}')"

echo "[INFO] Notified OpenClaw"
