#!/usr/bin/env bash
set -euo pipefail

: "${PUSHOVER_USER_KEY:?}"
: "${FORGEJO_PUSHOVER_TOKEN:?}"

EVENT_TYPE="${1:-}"

# Try all possible body sources
ARG_BODY="${2:-}"
STDIN_BODY=$(cat 2>/dev/null || true)
REQ_BODY="${HOOK_BODY:-}"

echo "DEBUG: argc=$# arg1=${1:-} arg2_len=${#ARG_BODY} stdin_len=${#STDIN_BODY} hookbody_len=${#REQ_BODY}" >&2
echo "DEBUG: all_args=$*" >&2

# Use whichever has content
PAYLOAD="${STDIN_BODY}"
[[ -z "${PAYLOAD}" ]] && PAYLOAD="${ARG_BODY}"
[[ -z "${PAYLOAD}" ]] && PAYLOAD="${REQ_BODY}"

echo "DEBUG: payload_len=${#PAYLOAD}" >&2
[[ -n "${PAYLOAD}" ]] && echo "DEBUG: payload_keys=$(echo "${PAYLOAD}" | jq -r 'keys[0:5] | join(",")' 2>&1)" >&2

TITLE=""
MESSAGE=""
PRIORITY=0
URL=""

case "${EVENT_TYPE}" in
    push)
        REPO=$(echo "${PAYLOAD}" | jq -r '.repository.full_name // .repository.name // ""')
        BRANCH=$(echo "${PAYLOAD}" | jq -r '.ref // "" | split("/") | last')
        PUSHER=$(echo "${PAYLOAD}" | jq -r '.pusher.username // .pusher.login // .sender.login // ""')
        COMMITS=$(echo "${PAYLOAD}" | jq -r '.commits | length')
        LAST_MSG=$(echo "${PAYLOAD}" | jq -r '(.commits[-1].message // "") | split("\n")[0]')
        COMPARE=$(echo "${PAYLOAD}" | jq -r '.compare_url // ""')
        TITLE="Push: ${REPO}"
        MESSAGE="${PUSHER} pushed ${COMMITS} commit(s) to ${BRANCH}\n${LAST_MSG}"
        URL="${COMPARE}"
        ;;
    pull_request)
        ACTION=$(echo "${PAYLOAD}" | jq -r '.action // ""')
        case "${ACTION}" in
            opened|closed|merged|reopened) ;;
            *) exit 0 ;;
        esac
        REPO=$(echo "${PAYLOAD}" | jq -r '.repository.full_name // ""')
        PR_TITLE=$(echo "${PAYLOAD}" | jq -r '.pull_request.title // ""')
        PR_NUMBER=$(echo "${PAYLOAD}" | jq -r '.pull_request.number // ""')
        PR_USER=$(echo "${PAYLOAD}" | jq -r '.pull_request.user.login // .pull_request.user.username // .sender.login // ""')
        PR_URL=$(echo "${PAYLOAD}" | jq -r '.pull_request.html_url // .pull_request.url // ""')
        TITLE="PR ${ACTION}: ${REPO}#${PR_NUMBER}"
        MESSAGE="${PR_TITLE}\nby ${PR_USER}"
        URL="${PR_URL}"
        ;;
    create)
        REF_TYPE=$(echo "${PAYLOAD}" | jq -r '.ref_type // ""')
        REF=$(echo "${PAYLOAD}" | jq -r '.ref // ""')
        REPO=$(echo "${PAYLOAD}" | jq -r '.repository.full_name // ""')
        TITLE="Created ${REF_TYPE}: ${REPO}"
        MESSAGE="${REF}"
        ;;
    release)
        ACTION=$(echo "${PAYLOAD}" | jq -r '.action // ""')
        [[ "${ACTION}" != "published" ]] && exit 0
        REPO=$(echo "${PAYLOAD}" | jq -r '.repository.full_name // ""')
        TAG=$(echo "${PAYLOAD}" | jq -r '.release.tag_name // ""')
        REL_URL=$(echo "${PAYLOAD}" | jq -r '.release.html_url // ""')
        TITLE="Release: ${REPO}"
        MESSAGE="${TAG}"
        URL="${REL_URL}"
        ;;
    repository)
        ACTION=$(echo "${PAYLOAD}" | jq -r '.action // ""')
        REPO=$(echo "${PAYLOAD}" | jq -r '.repository.full_name // ""')
        TITLE="Repo ${ACTION}: ${REPO}"
        MESSAGE="Repository ${ACTION}"
        PRIORITY=-1
        ;;
    *)
        # Ignore unknown events (ping, etc)
        exit 0
        ;;
esac

[[ -z "${MESSAGE}" ]] && exit 0

# Send to Pushover
curl -sf -X POST https://api.pushover.net/1/messages.json \
    -d "token=${FORGEJO_PUSHOVER_TOKEN}" \
    -d "user=${PUSHOVER_USER_KEY}" \
    -d "title=${TITLE}" \
    -d "message=${MESSAGE}" \
    -d "priority=${PRIORITY}" \
    ${URL:+-d "url=${URL}"} \
    ${URL:+-d "url_title=View on Forgejo"}
