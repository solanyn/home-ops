#!/usr/bin/env bash
set -euo pipefail

: "${PUSHOVER_USER_KEY:?}"
: "${FORGEJO_PUSHOVER_TOKEN:?}"

EVENT_TYPE="${1:-}"
PAYLOAD="${2:-}"

[[ -z "${PAYLOAD}" ]] && exit 0

TITLE=""
MESSAGE=""
PRIORITY=0
URL=""
NL=$'\n'

case "${EVENT_TYPE}" in
    push)
        REPO=$(echo "${PAYLOAD}" | jq -r '.repository.full_name // ""')
        BRANCH=$(echo "${PAYLOAD}" | jq -r '.ref // "" | split("/") | last')
        PUSHER=$(echo "${PAYLOAD}" | jq -r '.pusher.login // .pusher.username // .sender.login // ""')
        COMMITS=$(echo "${PAYLOAD}" | jq -r '.commits | length')
        LAST_MSG=$(echo "${PAYLOAD}" | jq -r '(.commits[-1].message // "") | split("\n")[0]')
        COMPARE=$(echo "${PAYLOAD}" | jq -r '.compare_url // ""')
        TITLE="Push: ${REPO}"
        MESSAGE="<b>${PUSHER}</b> pushed ${COMMITS} commit(s) to <b>${BRANCH}</b>${NL}<i>${LAST_MSG}</i>"
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
        MESSAGE="<b>${PR_TITLE}</b>${NL}by ${PR_USER}"
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
        MESSAGE="<b>${TAG}</b>"
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
        exit 0
        ;;
esac

[[ -z "${MESSAGE}" ]] && exit 0

curl -sf -X POST https://api.pushover.net/1/messages.json \
    -d "token=${FORGEJO_PUSHOVER_TOKEN}" \
    -d "user=${PUSHOVER_USER_KEY}" \
    -d "title=${TITLE}" \
    --data-urlencode "message=${MESSAGE}" \
    -d "html=1" \
    -d "priority=${PRIORITY}" \
    ${URL:+-d "url=${URL}"} \
    ${URL:+-d "url_title=View on Forgejo"}
