#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "${0}")/lib/common.sh"
export ROOT_DIR="$(git rev-parse --show-toplevel)"

readonly EXTENSION_CONFIG="${1:?}"

function main() {
    local -r LOG_LEVEL="info"
    
    check_cli op talosctl
    
    if ! op whoami --format=json &>/dev/null; then
        log error "Failed to authenticate with 1Password CLI"
    fi
    
    local extension_config
    
    if ! extension_config=$(render_template "${EXTENSION_CONFIG}") || [[ -z "${extension_config}" ]]; then
        exit 1
    fi
    
    echo "${extension_config}"
}

main "$@"