#!/bin/bash
# Undo scripts/howdy/enable-pam.sh: remove Howdy from sudo and the lock screen.
set -euo pipefail

SUDO=/etc/pam.d/sudo
KDE_FP=/etc/pam.d/kde-fingerprint

if [ "$(id -u)" -ne 0 ]; then
	echo "Run with sudo" >&2
	exit 1
fi

if [ -e "$SUDO.bak-howdy" ]; then
	cp "$SUDO.bak-howdy" "$SUDO"
	rm "$SUDO.bak-howdy"
else
	sed -i '\|/usr/lib/security/howdy/pam_howdy.so|d' "$SUDO"
fi
grep -nE 'howdy|common-auth' "$SUDO"

if [ -e "$KDE_FP" ] && grep -q 'scripts/howdy/enable-pam.sh' "$KDE_FP"; then
	rm "$KDE_FP"
	echo "removed $KDE_FP"
fi
echo "Done. To remove Howdy itself: sudo apt purge howdy"
