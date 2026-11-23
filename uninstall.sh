#!/usr/bin/env bash
set -Eeuo pipefail
log() { printf '[uninstall] %s\n' "$*"; }
fail() { printf '[uninstall] ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$EUID" -ne 0 ]] || fail "Run this uninstaller as the kiosk user, not with sudo."
KIOSK_SCRIPT="${KIOSK_SCRIPT:-${HOME}/scripts/kiosk.sh}"
[[ -f "$KIOSK_SCRIPT" ]] || fail "Kiosk script not found: $KIOSK_SCRIPT"
command -v python3 >/dev/null 2>&1 || fail "python3 is required."
export KIOSK_SCRIPT
python3 <<'PY'
import os, re, stat
from pathlib import Path
kiosk = Path(os.environ['KIOSK_SCRIPT'])
begin = '# BEGIN HP-PRO-TABLET-DISPLAY-ROTATION'
end = '# END HP-PRO-TABLET-DISPLAY-ROTATION'
content = kiosk.read_text(encoding='utf-8')
if (begin in content) != (end in content):
    raise SystemExit(f'ERROR: Incomplete managed marker block in {kiosk}; no changes made.')
pattern = re.compile(r'(?ms)^' + re.escape(begin) + r'\n.*?^' + re.escape(end) + r'\n?')
updated, count = pattern.subn('', content)
if count:
    mode = stat.S_IMODE(kiosk.stat().st_mode)
    kiosk.write_text(updated, encoding='utf-8')
    os.chmod(kiosk, mode)
    print(f'Removed display-rotation integration from {kiosk}')
else:
    print(f'No display-rotation integration found in {kiosk}')
backup = kiosk.with_name(kiosk.name + '.before-display-rotation')
if backup.exists(): print(f'Original backup retained: {backup}')
PY
bash -n "$KIOSK_SCRIPT" || fail "Kiosk script has a Bash syntax error after uninstall."
log "Uninstallation completed. Repository, config, packages, and backup were kept."
log "Restart the kiosk service or reboot to apply: sudo systemctl restart kiosk.service"
