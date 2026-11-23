#!/usr/bin/env bash
set -Eeuo pipefail

log() { printf '[install] %s\n' "$*"; }
fail() { printf '[install] ERROR: %s\n' "$*" >&2; exit 1; }

[[ "$EUID" -ne 0 ]] || fail "Run this installer as the kiosk user, not with sudo."
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROTATION_SCRIPT="${REPO_DIR}/scripts/configure-display.sh"
CONFIG_FILE="${REPO_DIR}/config/display.conf"
KIOSK_SCRIPT="${KIOSK_SCRIPT:-${HOME}/scripts/kiosk.sh}"

[[ -f "$CONFIG_FILE" ]] || fail "Configuration file not found: $CONFIG_FILE"
[[ -f "$KIOSK_SCRIPT" ]] || fail "Kiosk script not found: $KIOSK_SCRIPT"
[[ -f "$ROTATION_SCRIPT" ]] || fail "Rotation script not found: $ROTATION_SCRIPT"
command -v python3 >/dev/null 2>&1 || fail "python3 is required."
chmod +x "$ROTATION_SCRIPT"

missing_packages=()
command -v xrandr >/dev/null 2>&1 || missing_packages+=(x11-xserver-utils)
command -v xinput >/dev/null 2>&1 || missing_packages+=(xinput)
if ((${#missing_packages[@]} > 0)); then
    command -v sudo >/dev/null 2>&1 || fail "Missing tools: ${missing_packages[*]}. Install them with apt."
    log "Installing required packages: ${missing_packages[*]}"
    sudo apt-get update
    sudo apt-get install -y "${missing_packages[@]}"
fi

# shellcheck source=./config/display.conf
source "$CONFIG_FILE"
case "${DISPLAY_ROTATION:-}" in normal|left|right|inverted) ;; *) fail "DISPLAY_ROTATION must be normal, left, right, or inverted." ;; esac
[[ -n "${DISPLAY_OUTPUT:-}" ]] || fail "DISPLAY_OUTPUT must be set in config/display.conf."
[[ -n "${TOUCHSCREEN_NAME:-}" ]] || fail "TOUCHSCREEN_NAME must be set in config/display.conf."
bash -n "$ROTATION_SCRIPT" || fail "Rotation script has a Bash syntax error."
bash -n "$KIOSK_SCRIPT" || fail "Kiosk script has a Bash syntax error."

export ROTATION_SCRIPT KIOSK_SCRIPT
python3 <<'PY'
import os, re, shlex, stat
from pathlib import Path
kiosk = Path(os.environ['KIOSK_SCRIPT'])
rotation = os.environ['ROTATION_SCRIPT']
begin = '# BEGIN HP-PRO-TABLET-DISPLAY-ROTATION'
end = '# END HP-PRO-TABLET-DISPLAY-ROTATION'
content = kiosk.read_text(encoding='utf-8')
if (begin in content) != (end in content):
    raise SystemExit(f'ERROR: Incomplete managed marker block in {kiosk}; no changes made.')
pattern = re.compile(r'(?ms)^' + re.escape(begin) + r'\n.*?^' + re.escape(end) + r'\n?')
updated = pattern.sub('', content)
# Replace a previous manually added direct invocation of this same helper.
# This avoids running the rotation twice after adopting the installer.
manual_invocations = {rotation, shlex.quote(rotation), '"' + rotation + '"', "'" + rotation + "'"}
updated_lines = [line for line in updated.splitlines(keepends=True)
                 if line.strip() not in manual_invocations]
updated = ''.join(updated_lines)
block = (f'{begin}\n'
         '# Apply display and touchscreen orientation before starting the kiosk UI.\n'
         f'{shlex.quote(rotation)}\n'
         f'{end}\n')
lines = updated.splitlines(keepends=True)
if lines and lines[0].startswith('#!'):
    pos = 1
    if len(lines) > 1 and lines[1].strip() == '': pos = 2
    lines.insert(pos, block)
    updated = ''.join(lines)
else:
    updated = block + updated
if updated != content:
    backup = kiosk.with_name(kiosk.name + '.before-display-rotation')
    if not backup.exists():
        backup.write_text(content, encoding='utf-8')
        os.chmod(backup, stat.S_IMODE(kiosk.stat().st_mode))
        print(f'Created original backup: {backup}')
    mode = stat.S_IMODE(kiosk.stat().st_mode)
    kiosk.write_text(updated, encoding='utf-8')
    os.chmod(kiosk, mode)
    print(f'Updated kiosk script: {kiosk}')
else:
    print(f'Display-rotation integration already up to date in {kiosk}')
PY
bash -n "$KIOSK_SCRIPT" || fail "Updated kiosk script has a Bash syntax error."
log "Installation completed."
log "Restart the kiosk service or reboot to apply: sudo systemctl restart kiosk.service"
