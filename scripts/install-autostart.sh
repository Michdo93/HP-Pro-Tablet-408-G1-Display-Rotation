#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
AUTOSTART_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/autostart"
DESKTOP_FILE="${AUTOSTART_DIR}/hp-pro-tablet-display-rotation.desktop"
ROTATION_SCRIPT="${REPO_DIR}/scripts/configure-display.sh"

[[ -n "${HOME:-}" ]] || { printf 'ERROR: HOME is not set.\n' >&2; exit 1; }
[[ -x "${ROTATION_SCRIPT}" ]] || chmod +x "${ROTATION_SCRIPT}"

mkdir -p "${AUTOSTART_DIR}"

cat > "${DESKTOP_FILE}" <<EOF
[Desktop Entry]
Type=Application
Name=HP Pro Tablet Display Rotation
Comment=Apply the configured display rotation at desktop login
Exec=${ROTATION_SCRIPT}
Terminal=false
X-LXQt-Need-Tray=false
OnlyShowIn=LXQt;
EOF

chmod 0644 "${DESKTOP_FILE}"
printf 'Installed LXQt autostart entry: %s\n' "${DESKTOP_FILE}"
printf 'The repository must remain at: %s\n' "${REPO_DIR}"
printf 'Log out and back in, or reboot, to test autostart.\n'
