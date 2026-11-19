# HP Pro Tablet 408 G1 – Display Rotation

A small, configurable X11/LXQt helper to rotate the display on the HP Pro Tablet 408 G1 running Lubuntu.

This is an initial test version. It deliberately keeps the implementation simple:

- `xrandr` applies the display rotation.
- A per-user LXQt autostart entry runs the script when the graphical session starts.
- Touchscreen coordinate transformation is **not enabled automatically**. First verify whether the touchscreen follows the display rotation correctly on the actual tablet.

## Requirements

- Lubuntu / LXQt running an X11 session
- `xrandr`
- Bash

Check the session type:

```bash
echo "$XDG_SESSION_TYPE"
```

This initial version targets `x11`. It is not intended for a Wayland session.

Install `xrandr` if it is missing:

```bash
sudo apt update
sudo apt install x11-xserver-utils
```

## Quick start

Clone the repository:

```bash
git clone https://github.com/Michdo93/HP-Pro-Tablet-408-G1-Display-Rotation.git
cd HP-Pro-Tablet-408-G1-Display-Rotation
```

Inspect the available outputs:

```bash
xrandr --query
```

Edit `config/display.conf` if necessary. The default rotation is `right`:

```bash
nano config/display.conf
```

Supported values:

- `normal`
- `left` – 90 degrees counter-clockwise
- `right` – 90 degrees clockwise
- `inverted` – 180 degrees

Test manually before installing autostart:

```bash
./scripts/configure-display.sh
```

To restore the normal orientation:

```bash
DISPLAY_ROTATION=normal ./scripts/configure-display.sh
```

## Install LXQt autostart

Run this as the desktop user, without `sudo`:

```bash
./scripts/install-autostart.sh
```

The installer creates a per-user `.desktop` entry in:

```text
~/.config/autostart/
```

Log out and back in, or reboot, to test automatic application.

The autostart entry points to the cloned repository. Keep the repository in a stable location after installing it.

## Uninstall autostart

Run:

```bash
./scripts/uninstall-autostart.sh
```

This removes only the autostart entry. It does not delete the cloned repository.

## Display detection

The script selects the first connected output matching these rules:

1. A connected output marked as `primary`.
2. Otherwise, a connected internal panel whose name begins with `eDP`, `DSI`, or `LVDS`.
3. Otherwise, if exactly one output is connected, that output.
4. If the result is ambiguous, the script stops and asks for an explicit output name.

You can set the output explicitly in `config/display.conf`, for example:

```bash
DISPLAY_OUTPUT="DSI-1"
```

Use the exact output name shown by `xrandr --query`.

## Touchscreen

Touchscreen mapping is intentionally left unchanged in this first version. Depending on the driver and desktop stack, the touchscreen may rotate automatically with the display, or it may require a coordinate transformation.

After rotating the display, test touch input at all four corners and near the centre. If touch coordinates are wrong, collect:

```bash
xinput list
xinput list-props "EXACT TOUCHSCREEN DEVICE NAME"
```

Do not guess or apply a transformation matrix before identifying the correct input device and testing the actual behaviour. The touchscreen implementation can then be added to the configuration based on the tablet's output.

## Troubleshooting

### `Can't open display` / display cannot be opened

Run the script from the logged-in graphical desktop session, not from a plain SSH session or a system-level service.

### No output detected

Run:

```bash
xrandr --query
```

Then set `DISPLAY_OUTPUT` explicitly in `config/display.conf`.

### Wrong rotation direction

Try the other value, `left` or `right`, in `config/display.conf`.

### Restore the original orientation

```bash
DISPLAY_ROTATION=normal ./scripts/configure-display.sh
```

## Notes

- No systemd service is required for this use case.
- The scripts do not use `sudo`.
- The configuration is loaded from the repository's `config/display.conf`.
- This is an initial version intended for testing on the physical tablet. Confirm the output name, rotation direction, and touchscreen behaviour before treating the configuration as final.
