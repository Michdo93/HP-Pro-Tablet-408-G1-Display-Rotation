
#!/usr/bin/env bash
set -Eeuo pipefail

# Default X11 display for the standalone kiosk session.
export DISPLAY="${DISPLAY:-:0}"

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

command -v xrandr >/dev/null 2>&1 || fail "xrandr is not installed."

# Load configuration.
# shellcheck source=../config/display.conf
source "${CONFIG_FILE}"

ROTATION="${DISPLAY_ROTATION:-right}"
OUTPUT="${DISPLAY_OUTPUT:-}"
TOUCHSCREEN="${TOUCHSCREEN_NAME:-}"

case "${ROTATION}" in
    normal)
        MATRIX=(1 0 0 0 1 0 0 0 1)
        ;;
    left)
        MATRIX=(0 -1 1 1 0 0 0 0 1)
        ;;
    right)
        MATRIX=(0 1 0 -1 0 1 0 0 1)
        ;;
    inverted)
        MATRIX=(-1 0 1 0 -1 1 0 0 1)
        ;;
    *)
        fail "Unsupported rotation: ${ROTATION}"
        ;;
esac

[[ -n "${DISPLAY:-}" ]] || fail "DISPLAY is not set."

XRANDR_OUTPUT="$(xrandr --query)" || fail "Could not query XRandR."

# Detect display output if not explicitly configured.
if [[ -z "${OUTPUT}" ]]; then
    OUTPUT="$(awk '
        /^[^[:space:]].* connected primary([[:space:]]|$)/ {
            print $1
            exit
        }
    ' <<< "${XRANDR_OUTPUT}")"

    if [[ -z "${OUTPUT}" ]]; then
        OUTPUT="$(awk '
            /^[^[:space:]].* connected([[:space:]]|$)/ {
                if ($1 ~ /^(eDP|DSI|LVDS)/) {
                    print $1
                    exit
                }
            }
        ' <<< "${XRANDR_OUTPUT}")"
    fi

    if [[ -z "${OUTPUT}" ]]; then
        mapfile -t CONNECTED_OUTPUTS < <(
            awk '/^[^[:space:]].* connected([[:space:]]|$)/ {print $1}' <<< "${XRANDR_OUTPUT}"
        )

        if [[ "${#CONNECTED_OUTPUTS[@]}" -eq 1 ]]; then
            OUTPUT="${CONNECTED_OUTPUTS[0]}"
        else
            fail "Could not uniquely identify display output."
        fi
    fi
fi

log "Applying rotation '${ROTATION}' to output '${OUTPUT}'."
xrandr --output "${OUTPUT}" --rotate "${ROTATION}"

# Configure touchscreen if a device name is specified.
if [[ -n "${TOUCHSCREEN}" ]]; then
    command -v xinput >/dev/null 2>&1 || fail "xinput is not installed."

    # Wait briefly for the touchscreen to become available.
    DEVICE_FOUND=false

    for attempt in {1..10}; do
        if xinput list --name-only | grep -Fxq -- "${TOUCHSCREEN}"; then
            DEVICE_FOUND=true
            break
        fi
        sleep 1
    done

    if [[ "${DEVICE_FOUND}" != true ]]; then
        fail "Touchscreen '${TOUCHSCREEN}' was not found."
    fi

    log "Applying touchscreen transformation to '${TOUCHSCREEN}'."

    xinput set-prop "${TOUCHSCREEN}" \
        "Coordinate Transformation Matrix" \
        "${MATRIX[@]}"

    log "Touchscreen transformation applied."
else
    log "No touchscreen configured. Skipping touchscreen transformation."
fi

log "Display configuration completed."
