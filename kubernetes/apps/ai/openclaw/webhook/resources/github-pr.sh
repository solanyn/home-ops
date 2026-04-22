#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-}"
PR_TITLE="${2:-}"
PR_NUMBER="${3:-}"
REPO="${4:-}"
PR_USER="${5:-}"
PR_BRANCH="${6:-}"
PR_URL="${7:-}"

: "${OPENCLAW_HOOKS_TOKEN:?}"

case "${ACTION}" in
    opened|synchronize|reopened) ;;
    *) exit 0 ;;
esac

MESSAGE="GitHub PR ${ACTION}: #${PR_NUMBER} \"${PR_TITLE}\" by ${PR_USER} on ${REPO} (${PR_BRANCH}). URL: ${PR_URL}. Review the diff with: gh pr diff ${PR_NUMBER} --repo ${REPO}. If Renovate: check if safe and report with merge recommendation."

curl -sf -X POST http://openclaw.ai.svc.cluster.local:18789/hooks/agent \
    -H "Authorization: Bearer ${OPENCLAW_HOOKS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg msg "${MESSAGE}" '{message: $msg, name: "GitHub PR"}')"
