#!/bin/bash
# Install the 60%/100% battery charge limit switch.
# Undo: sudo rm /usr/local/bin/battery-limit /usr/local/libexec/battery-limit-helper \
#         /usr/share/polkit-1/actions/org.local.battery-limit.policy \
#         /usr/share/applications/battery-limit.desktop
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

if [ "$(id -u)" -ne 0 ]; then
	echo "Run with sudo" >&2
	exit 1
fi
if [ ! -w /sys/class/power_supply/BAT0/charge_types ]; then
	echo "/sys/class/power_supply/BAT0/charge_types not found (dell-laptop driver)" >&2
	exit 1
fi

install -D -m 755 "$DIR/battery-limit-helper" /usr/local/libexec/battery-limit-helper
install -D -m 755 "$DIR/battery-limit" /usr/local/bin/battery-limit
install -D -m 644 "$DIR/org.local.battery-limit.policy" /usr/share/polkit-1/actions/org.local.battery-limit.policy
install -D -m 644 "$DIR/battery-limit.desktop" /usr/share/applications/battery-limit.desktop
echo "Installed. Try: battery-limit 60"
