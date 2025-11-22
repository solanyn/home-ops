#!/usr/bin/env bash
set -euo pipefail

PAYLOAD=${1:-}

: "${APPRISE_LIDARR_PUSHOVER_URL:?Pushover URL required}"

echo "[DEBUG] Lidarr Payload: ${PAYLOAD}"

function _jq() {
    jq -r "${1:?}" <<<"${PAYLOAD}"
}

function notify() {
    local event_type=$(_jq '.eventType')

    case "${event_type}" in
    "Download")
        printf -v PUSHOVER_TITLE "Album %s" \
            "$([[ "$(_jq '.isUpgrade')" == "true" ]] && echo "Upgraded" || echo "Added")"
        printf -v PUSHOVER_MESSAGE "<b>%s - %s</b><small>\n\n<b>Client:</b> %s</small>" \
            "$(_jq '.artist.name')" \
            "$(_jq '.album.title')" \
            "$(_jq '.downloadClient')"
        printf -v PUSHOVER_URL "%s/album/%s" \
            "$(_jq '.applicationUrl')" \
            "$(_jq '.album.id')"
        printf -v PUSHOVER_URL_TITLE "View Album"
        printf -v PUSHOVER_PRIORITY "low"
        ;;
    "ManualInteractionRequired")
        printf -v PUSHOVER_TITLE "Album Requires Manual Interaction"
        printf -v PUSHOVER_MESSAGE "<b>%s - %s</b><small>\n<b>Client:</b> %s</small>" \
            "$(_jq '.artist.name')" \
            "$(_jq '.album.title')" \
            "$(_jq '.downloadClient')"
        printf -v PUSHOVER_URL "%s/activity/queue" "$(_jq '.applicationUrl')"
        printf -v PUSHOVER_URL_TITLE "View Queue"
        printf -v PUSHOVER_PRIORITY "high"
        ;;
    "Test")
        printf -v PUSHOVER_TITLE "Test Notification"
        printf -v PUSHOVER_MESSAGE "Howdy this is a test notification"
        printf -v PUSHOVER_URL "%s" "$(_jq '.applicationUrl')"
        printf -v PUSHOVER_URL_TITLE "View Music"
        printf -v PUSHOVER_PRIORITY "low"
        ;;
    *)
        echo "[ERROR] Unknown event type: ${event_type}" >&2
        return 1
        ;;
    esac

    apprise -vv --title "${PUSHOVER_TITLE}" --body "${PUSHOVER_MESSAGE}" --input-format html \
        "${APPRISE_LIDARR_PUSHOVER_URL}?url=${PUSHOVER_URL}&url_title=${PUSHOVER_URL_TITLE}&priority=${PUSHOVER_PRIORITY}&format=html"
}

function main() {
    notify
}

main "$@"
