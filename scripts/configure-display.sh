#!/usr/bin/env bash
set -Eeuo pipefail

# Standalone kiosk uses X11 display :0; keep an existing DISPLAY if provided.
export DISPLAY="${DISPLAY:-:0}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${REPO_DIR}/config/display.conf"

log() { printf '[display-rotation] %s\n' "$*"; }
fail() { printf '[display-rotation] ERROR: %s\n' "$*" >&2; exit 1; }
[[ -f "$CONFIG_FILE" ]] || fail "Configuration file not found: $CONFIG_FILE"
command -v xrandr >/dev/null 2>&1 || fail "xrandr is not installed."
command -v xinput >/dev/null 2>&1 || fail "xinput is not installed."
# shellcheck source=../config/display.conf
source "$CONFIG_FILE"
ROTATION="${DISPLAY_ROTATION:-right}"
OUTPUT="${DISPLAY_OUTPUT:-}"
TOUCHSCREEN="${TOUCHSCREEN_NAME:-}"
case "$ROTATION" in
    normal) MATRIX=(1 0 0 0 1 0 0 0 1) ;;
    left) MATRIX=(0 -1 1 1 0 0 0 0 1) ;;
    right) MATRIX=(0 1 0 -1 0 1 0 0 1) ;;
    inverted) MATRIX=(-1 0 1 0 -1 1 0 0 1) ;;
    *) fail "Unsupported DISPLAY_ROTATION '$ROTATION'. Use normal, left, right, or inverted." ;;
esac
XRANDR_OUTPUT="$(xrandr --query)" || fail "Could not query XRandR. Is the X11 session available?"
if [[ -z "$OUTPUT" ]]; then
    OUTPUT="$(awk '/^[^[:space:]].* connected primary([[:space:]]|$)/ {print $1; exit}' <<< "$XRANDR_OUTPUT")"
    if [[ -z "$OUTPUT" ]]; then
        OUTPUT="$(awk '/^[^[:space:]].* connected([[:space:]]|$)/ {if ($1 ~ /^(eDP|DSI|LVDS)/) {print $1; exit}}' <<< "$XRANDR_OUTPUT")"
    fi
    if [[ -z "$OUTPUT" ]]; then
        mapfile -t CONNECTED_OUTPUTS < <(awk '/^[^[:space:]].* connected([[:space:]]|$)/ {print $1}' <<< "$XRANDR_OUTPUT")
        ((${#CONNECTED_OUTPUTS[@]} == 1)) && OUTPUT="${CONNECTED_OUTPUTS[0]}"
    fi
fi
[[ -n "$OUTPUT" ]] || fail "Could not uniquely identify display output. Set DISPLAY_OUTPUT in config/display.conf."
awk -v output="$OUTPUT" '$1 == output && $2 == "connected" {found=1} END {exit(found ? 0 : 1)}' <<< "$XRANDR_OUTPUT" \
    || fail "Configured display output '$OUTPUT' is not connected."
log "Applying rotation '$ROTATION' to output '$OUTPUT'."
xrandr --output "$OUTPUT" --rotate "$ROTATION"
if [[ -n "$TOUCHSCREEN" ]]; then
    found=false
    for attempt in {1..10}; do
        if xinput list --name-only | grep -Fxq -- "$TOUCHSCREEN"; then found=true; break; fi
        sleep 1
    done
    [[ "$found" == true ]] || fail "Touchscreen '$TOUCHSCREEN' was not found."
    log "Applying touchscreen transformation to '$TOUCHSCREEN'."
    xinput set-prop "$TOUCHSCREEN" "Coordinate Transformation Matrix" "${MATRIX[@]}"
    log "Touchscreen transformation applied."
else
    log "TOUCHSCREEN_NAME is empty; skipping touchscreen transformation."
fi
log "Display configuration completed."
