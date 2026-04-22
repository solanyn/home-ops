#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-}"
CONCLUSION="${2:-}"
WORKFLOW="${3:-}"
REPO="${4:-}"
BRANCH="${5:-}"
SHA="${6:-}"

: "${OPENCLAW_HOOKS_TOKEN:?OpenClaw hooks token required}"

if [[ "${ACTION}" != "completed" ]]; then
    echo "[INFO] Ignoring action: ${ACTION}"
    exit 0
fi

echo "[INFO] CI ${CONCLUSION}: ${WORKFLOW} on ${REPO} (${BRANCH}) @ ${SHA:0:7}"

MESSAGE="GitHub CI completed: ${WORKFLOW} on ${REPO} (${BRANCH}) — conclusion: ${CONCLUSION}, sha: ${SHA:0:7}."

if [[ "${CONCLUSION}" == "success" ]]; then
    MESSAGE="${MESSAGE} Check if the relevant service deployed via Flux (kubectl via ssh mac.internal). Report result to Andrew on Matrix."
elif [[ "${CONCLUSION}" == "failure" ]]; then
    MESSAGE="${MESSAGE} Build failed. Check run logs with: gh run view --repo ${REPO} --json jobs. Report failure to Andrew on Matrix."
fi

curl -sf -X POST http://openclaw.ai.svc.cluster.local:18789/hooks/agent \
    -H "Authorization: Bearer ${OPENCLAW_HOOKS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg msg "${MESSAGE}" '{message: $msg, name: "CI Notify"}')"

echo "[INFO] Notified OpenClaw"
