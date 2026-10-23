#!/bin/bash
# Undo scripts/install.sh: remove the DKMS module and restore /etc/default/grub.
# Reboot afterwards.
set -euo pipefail

PKG=dell5290-tps68470
VER=1.0
GRUB=/etc/default/grub
BACKUP=/etc/default/grub.bak-dell5290

if [ "$(id -u)" -ne 0 ]; then
	echo "Run with sudo" >&2
	exit 1
fi

echo "== DKMS module"
if dkms status -m "$PKG" -v "$VER" | grep -q .; then
	dkms remove "$PKG/$VER" --all
fi
rm -rf "/usr/src/$PKG-$VER"

echo "== GRUB"
if [ -e "$BACKUP" ]; then
	cp "$BACKUP" "$GRUB"
	rm "$BACKUP"
else
	sed -i -E "s/ ?acpi_enforce_resources=lax//" "$GRUB"
fi
grep -E '^GRUB_(TIMEOUT|TIMEOUT_STYLE|CMDLINE_LINUX_DEFAULT)=' "$GRUB"
update-grub

echo
echo "Done. Reboot to go back to the stock driver."
