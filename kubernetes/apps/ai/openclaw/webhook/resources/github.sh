#!/usr/bin/env bash
set -euo pipefail

: "${OPENCLAW_HOOKS_TOKEN:?}"

EVENT_TYPE="${1:-}"
PAYLOAD=$(cat)

case "${EVENT_TYPE}" in
    workflow_run)
        ACTION=$(echo "${PAYLOAD}" | jq -r '.action // ""')
        [[ "${ACTION}" != "completed" ]] && exit 0
        CONCLUSION=$(echo "${PAYLOAD}" | jq -r '.workflow_run.conclusion // ""')
        WORKFLOW=$(echo "${PAYLOAD}" | jq -r '.workflow_run.name // ""')
        REPO=$(echo "${PAYLOAD}" | jq -r '.repository.full_name // ""')
        BRANCH=$(echo "${PAYLOAD}" | jq -r '.workflow_run.head_branch // ""')
        SHA=$(echo "${PAYLOAD}" | jq -r '.workflow_run.head_sha // ""')
        MESSAGE="GitHub CI completed: ${WORKFLOW} on ${REPO} (${BRANCH}) — ${CONCLUSION}, sha: ${SHA:0:7}."
        if [[ "${CONCLUSION}" == "success" ]]; then
            MESSAGE="${MESSAGE} Check if the relevant service deployed via Flux. Report result."
        elif [[ "${CONCLUSION}" == "failure" ]]; then
            MESSAGE="${MESSAGE} Build failed. Check run logs with: gh run view --repo ${REPO} --json jobs. Report failure."
        fi
        ;;
    pull_request)
        ACTION=$(echo "${PAYLOAD}" | jq -r '.action // ""')
        case "${ACTION}" in
            opened|synchronize|reopened) ;;
            *) exit 0 ;;
        esac
        PR_TITLE=$(echo "${PAYLOAD}" | jq -r '.pull_request.title // ""')
        PR_NUMBER=$(echo "${PAYLOAD}" | jq -r '.pull_request.number // ""')
        REPO=$(echo "${PAYLOAD}" | jq -r '.repository.full_name // ""')
        PR_USER=$(echo "${PAYLOAD}" | jq -r '.pull_request.user.login // ""')
        PR_BRANCH=$(echo "${PAYLOAD}" | jq -r '.pull_request.head.ref // ""')
        PR_URL=$(echo "${PAYLOAD}" | jq -r '.pull_request.html_url // ""')
        MESSAGE="GitHub PR ${ACTION}: #${PR_NUMBER} \"${PR_TITLE}\" by ${PR_USER} on ${REPO} (${PR_BRANCH}). URL: ${PR_URL}. Review the diff with: gh pr diff ${PR_NUMBER} --repo ${REPO}. If Renovate: check if safe and report with merge recommendation."
        ;;
    ping)
        exit 0
        ;;
    *)
        exit 0
        ;;
esac

curl -sf -X POST http://openclaw.ai.svc.cluster.local:18789/hooks/agent \
    -H "Authorization: Bearer ${OPENCLAW_HOOKS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg msg "${MESSAGE}" '{message: $msg, name: "GitHub"}')"
