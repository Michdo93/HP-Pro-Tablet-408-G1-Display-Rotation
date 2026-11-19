#!/usr/bin/env bash
set -Eeuo pipefail

AUTOSTART_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/autostart"
DESKTOP_FILE="${AUTOSTART_DIR}/hp-pro-tablet-display-rotation.desktop"

if [[ -f "${DESKTOP_FILE}" ]]; then
    rm -- "${DESKTOP_FILE}"
    printf 'Removed autostart entry: %s\n' "${DESKTOP_FILE}"
else
    printf 'No autostart entry found at: %s\n' "${DESKTOP_FILE}"
fi
