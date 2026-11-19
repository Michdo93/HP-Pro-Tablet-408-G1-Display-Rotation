#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${REPO_DIR}/config/display.conf"

log() {
    printf '[display-rotation] %s\n' "$*"
}

fail() {
    printf '[display-rotation] ERROR: %s\n' "$*" >&2
    exit 1
}

[[ -f "${CONFIG_FILE}" ]] || fail "Configuration file not found: ${CONFIG_FILE}"
command -v xrandr >/dev/null 2>&1 || fail "'xrandr' is not installed. Install x11-xserver-utils."

# shellcheck source=../config/display.conf
source "${CONFIG_FILE}"

ROTATION="${DISPLAY_ROTATION:-right}"
OUTPUT="${DISPLAY_OUTPUT:-}"

case "${ROTATION}" in
    normal|left|right|inverted) ;;
    *) fail "Unsupported DISPLAY_ROTATION '${ROTATION}'. Use normal, left, right, or inverted." ;;
esac

if [[ -z "${DISPLAY:-}" ]]; then
    fail "DISPLAY is not set. Run this script from the logged-in X11 desktop session."
fi

XRANDR_OUTPUT="$(xrandr --query)" || fail "Could not query XRandR. Is the X11 session available?"

if [[ -z "${OUTPUT}" ]]; then
    # Prefer an output explicitly marked as primary.
    OUTPUT="$(awk '
        /^[^[:space:]].* connected primary([[:space:]]|$)/ { print $1; exit }
    ' <<< "${XRANDR_OUTPUT}")"

    # Otherwise prefer a connected internal panel.
    if [[ -z "${OUTPUT}" ]]; then
        OUTPUT="$(awk '
            /^[^[:space:]].* connected([[:space:]]|$)/ {
                name = $1
                if (name ~ /^(eDP|DSI|LVDS)/) {
                    print name
                    exit
                }
            }
        ' <<< "${XRANDR_OUTPUT}")"
    fi

    # As a final fallback, accept exactly one connected output.
    if [[ -z "${OUTPUT}" ]]; then
        mapfile -t CONNECTED_OUTPUTS < <(
            awk '/^[^[:space:]].* connected([[:space:]]|$)/ { print $1 }' <<< "${XRANDR_OUTPUT}"
        )
        if [[ "${#CONNECTED_OUTPUTS[@]}" -eq 1 ]]; then
            OUTPUT="${CONNECTED_OUTPUTS[0]}"
        elif [[ "${#CONNECTED_OUTPUTS[@]}" -gt 1 ]]; then
            fail "Multiple outputs are connected and no internal/primary output was identified. Set DISPLAY_OUTPUT in config/display.conf."
        fi
    fi
fi

[[ -n "${OUTPUT}" ]] || fail "No connected display output was detected. Check 'xrandr --query' and set DISPLAY_OUTPUT if needed."

if ! awk -v output="${OUTPUT}" '
    $1 == output && $2 == "connected" { found = 1 }
    END { exit(found ? 0 : 1) }
' <<< "${XRANDR_OUTPUT}"; then
    fail "Configured output '${OUTPUT}' is not reported as connected by xrandr."
fi

log "Applying rotation '${ROTATION}' to output '${OUTPUT}'."
xrandr --output "${OUTPUT}" --rotate "${ROTATION}"
log "Display rotation applied."
log "Touchscreen mapping has not been changed by this script."
