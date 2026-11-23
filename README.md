# HP Pro Tablet 408 G1 – Display Rotation

Configure display and touchscreen rotation on an HP Pro Tablet 408 G1 running Lubuntu/X11 in a standalone kiosk setup.

The expected startup chain is `systemd` → `kiosk.service` → `startx` → `~/scripts/kiosk.sh` → Matchbox and Chromium. The installer inserts the rotation command into the existing kiosk script. It does not create another systemd service and does not use LXQt autostart.

## Features

- Rotate the display using `xrandr`.
- Rotate touchscreen coordinates using `xinput`.
- Support `normal`, `left`, `right`, and `inverted`.
- Integrate into an existing kiosk startup script.
- Idempotent installation; no duplicate managed blocks.
- Uninstall only the block managed by this project.

## Tested HP Pro Tablet 408 G1 configuration

| Component | Value |
|---|---|
| Display output | `DSI-1` |
| Rotation | `right` |
| Touchscreen | `SYNA7508:00 06CB:125D` |
| X11 display | `:0` |

The numeric XInput ID is not used because it can change after reboot. The stylus is a separate input device and is not configured by this initial version.

## Requirements

- Lubuntu with X11, `systemd`, `startx`
- Existing kiosk script at `~/scripts/kiosk.sh`
- `xrandr` (`x11-xserver-utils`), `xinput`, `python3`
- `sudo` access to install missing packages

## Installation

Run as the kiosk user (not with `sudo`):

```bash
git clone https://github.com/Michdo93/HP-Pro-Tablet-408-G1-Display-Rotation.git
cd HP-Pro-Tablet-408-G1-Display-Rotation
nano config/display.conf
chmod +x install.sh uninstall.sh scripts/configure-display.sh
./install.sh
```

Default configuration:

```bash
DISPLAY_OUTPUT="DSI-1"
DISPLAY_ROTATION="right"
TOUCHSCREEN_NAME="SYNA7508:00 06CB:125D"
```

The installer checks the configuration and kiosk script, installs missing runtime packages using `sudo`, creates `~/scripts/kiosk.sh.before-display-rotation` on first modification, and inserts a marked call to `configure-display.sh` immediately after the kiosk script's shebang. Repeated installations update the managed block rather than duplicating it.

The installer does not restart the kiosk automatically. Apply the change with:

```bash
sudo systemctl restart kiosk.service
```

Or reboot:

```bash
sudo reboot
```

## Manual test and verification

From the running X11 session:

```bash
./scripts/configure-display.sh
DISPLAY=:0 xrandr --query
DISPLAY=:0 xinput list-props "SYNA7508:00 06CB:125D"
```

For `right`, the expected touchscreen matrix is:

```text
0.000000, 1.000000, 0.000000,
-1.000000, 0.000000, 1.000000,
0.000000, 0.000000, 1.000000
```

## Rotation values

| Value | Orientation |
|---|---|
| `normal` | Default orientation |
| `left` | 90 degrees counter-clockwise |
| `right` | 90 degrees clockwise |
| `inverted` | 180 degrees |

If device names differ, inspect them with:

```bash
DISPLAY=:0 xrandr --query
DISPLAY=:0 xinput list
```

Use the exact touchscreen name, not its numeric XInput ID.

## Kiosk integration details

The installer inserts this managed block into `~/scripts/kiosk.sh`:

```bash
# BEGIN HP-PRO-TABLET-DISPLAY-ROTATION
# Apply display and touchscreen orientation before starting the kiosk UI.
/path/to/repository/scripts/configure-display.sh
# END HP-PRO-TABLET-DISPLAY-ROTATION
```

The actual absolute path is generated automatically. The command runs after `startx` has brought up X11, which is required by `xrandr` and `xinput`.

**Important:** If the kiosk setup script is run again and recreates `~/scripts/kiosk.sh`, it may overwrite the integration block. Run `./install.sh` again afterwards.

## Logs and troubleshooting

```bash
sudo systemctl status kiosk.service
journalctl -u kiosk.service -b --no-pager
```

The rotation helper logs messages prefixed with `[display-rotation]`. If it cannot connect to X11, ensure it is invoked from `kiosk.sh` after `startx` starts the X server. If the touchscreen is not found, check its exact name with `DISPLAY=:0 xinput list`.

## Uninstallation

Run as the kiosk user, without `sudo`:

```bash
./uninstall.sh
```

The uninstaller removes only the marked display-rotation block from `~/scripts/kiosk.sh`. It keeps the repository, configuration, original backup, and installed packages. It does not remove or modify `kiosk.service`.

Restart the kiosk service or reboot to apply the removal:

```bash
sudo systemctl restart kiosk.service
```

For a custom kiosk script path, provide it to both scripts:

```bash
KIOSK_SCRIPT="/path/to/kiosk.sh" ./install.sh
KIOSK_SCRIPT="/path/to/kiosk.sh" ./uninstall.sh
```

## License

MIT. See [LICENSE](LICENSE).
