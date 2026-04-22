#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-}"
CONCLUSION="${2:-}"
WORKFLOW="${3:-}"
REPO="${4:-}"
BRANCH="${5:-}"
SHA="${6:-}"

: "${OPENCLAW_HOOKS_TOKEN:?}"

[[ "${ACTION}" != "completed" ]] && exit 0

MESSAGE="GitHub CI completed: ${WORKFLOW} on ${REPO} (${BRANCH}) — ${CONCLUSION}, sha: ${SHA:0:7}."

if [[ "${CONCLUSION}" == "success" ]]; then
    MESSAGE="${MESSAGE} Check if the relevant service deployed via Flux. Report result."
elif [[ "${CONCLUSION}" == "failure" ]]; then
    MESSAGE="${MESSAGE} Build failed. Check run logs with: gh run view --repo ${REPO} --json jobs. Report failure."
fi

curl -sf -X POST http://openclaw.ai.svc.cluster.local:18789/hooks/agent \
    -H "Authorization: Bearer ${OPENCLAW_HOOKS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg msg "${MESSAGE}" '{message: $msg, name: "CI Notify"}')"
