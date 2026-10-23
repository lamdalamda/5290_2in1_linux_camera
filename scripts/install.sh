#!/bin/bash
# Enable the OV5670 front camera on a Dell Latitude 5290 2-in-1.
#
#  1. Build and install the patched TPS68470 PMIC module with DKMS
#  2. Add acpi_enforce_resources=lax to the kernel command line
#  3. With --show-grub-menu, also show the GRUB menu for 5 seconds
#
# Reboot afterwards. Undo with scripts/uninstall.sh.
set -euo pipefail

PKG=dell5290-tps68470
VER=1.0
PARAM=acpi_enforce_resources=lax
GRUB=/etc/default/grub
BACKUP=/etc/default/grub.bak-dell5290
SRC="$(cd "$(dirname "$0")/.." && pwd)/dkms/$PKG-$VER"

show_menu=0
for arg in "$@"; do
	case "$arg" in
	--show-grub-menu) show_menu=1 ;;
	-h|--help) sed -n '2,9p' "$0"; exit 0 ;;
	*) echo "Unknown option: $arg" >&2; exit 1 ;;
	esac
done

if [ "$(id -u)" -ne 0 ]; then
	echo "Run with sudo" >&2
	exit 1
fi

product=$(cat /sys/class/dmi/id/product_name)
if [ "$product" != "Latitude 5290 2-in-1" ]; then
	echo "This is a '$product', not a Latitude 5290 2-in-1. Stopping." >&2
	exit 1
fi

for cmd in dkms make gcc; do
	if ! command -v "$cmd" >/dev/null; then
		echo "Missing $cmd. Install with: sudo apt install build-essential dkms" >&2
		exit 1
	fi
done

echo "== DKMS module"
if dkms status -m "$PKG" -v "$VER" | grep -q .; then
	dkms remove "$PKG/$VER" --all
fi
rm -rf "/usr/src/$PKG-$VER"
cp -r "$SRC" "/usr/src/$PKG-$VER"
dkms add "$PKG/$VER"
dkms build "$PKG/$VER"
dkms install "$PKG/$VER"

echo "== GRUB"
[ -e "$BACKUP" ] || cp "$GRUB" "$BACKUP"
if grep -q "^GRUB_CMDLINE_LINUX_DEFAULT=.*$PARAM" "$GRUB"; then
	echo "$PARAM already set"
else
	sed -i -E "s/^(GRUB_CMDLINE_LINUX_DEFAULT=)(['\"])(.*)\2/\1\2\3 $PARAM\2/" "$GRUB"
	sed -i -E "s/^(GRUB_CMDLINE_LINUX_DEFAULT=['\"]) /\1/" "$GRUB"
fi
if [ "$show_menu" -eq 1 ]; then
	sed -i -e "s/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/" \
		-e "s/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=5/" "$GRUB"
fi
grep -E '^GRUB_(TIMEOUT|TIMEOUT_STYLE|CMDLINE_LINUX_DEFAULT)=' "$GRUB"
update-grub

echo
echo "Done. Reboot, then run scripts/check.sh"
