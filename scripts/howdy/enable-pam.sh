#!/bin/bash
# Use Howdy to unlock the KDE lock screen. Passwords keep working.
#
#  lock screen  The KDE lock screen runs the kde-fingerprint PAM service in the
#               background next to the password field. Howdy goes there, so
#               the password field stays usable while Howdy looks for a face.
#  --sudo       Also try Howdy first for sudo (off by default: any program you
#               run could then get root while you sit in front of the camera)
#
# Not touched: SDDM login (it must stay password-only to unlock KWallet), su,
# polkit, and everything else in common-auth.
#
# Undo: scripts/howdy/disable-pam.sh
set -euo pipefail

with_sudo=0
for arg in "$@"; do
	case "$arg" in
	--sudo) with_sudo=1 ;;
	*) echo "Unknown option: $arg" >&2; exit 1 ;;
	esac
done

HOWDY=/usr/lib/security/howdy/pam_howdy.so
LINE="auth       sufficient   $HOWDY"
SUDO=/etc/pam.d/sudo
KDE_FP=/etc/pam.d/kde-fingerprint

if [ "$(id -u)" -ne 0 ]; then
	echo "Run with sudo" >&2
	exit 1
fi
if [ ! -e "$HOWDY" ]; then
	echo "$HOWDY not found. Run scripts/howdy/install.sh first." >&2
	exit 1
fi
if [ -e "$KDE_FP" ] && ! grep -q 'scripts/howdy/enable-pam.sh' "$KDE_FP"; then
	echo "$KDE_FP already exists and was not written by this script. Stopping." >&2
	exit 1
fi

if [ "$with_sudo" -eq 1 ]; then
	echo "== sudo"
	[ -e "$SUDO.bak-howdy" ] || cp "$SUDO" "$SUDO.bak-howdy"
	if grep -q "$HOWDY" "$SUDO"; then
		echo "already enabled"
	else
		sed -i "s|^@include common-auth|$LINE\n@include common-auth|" "$SUDO"
	fi
	grep -nE 'howdy|common-auth' "$SUDO"
fi

echo "== KDE lock screen ($KDE_FP)"
cat > "$KDE_FP" <<EOF
#%PAM-1.0
# Written by 5290_2in1_linux_camera scripts/howdy/enable-pam.sh
# The KDE lock screen runs this service in the background, next to the
# password prompt (which uses the "kde" service, falling back to "other").
auth       sufficient   $HOWDY
auth       required     pam_deny.so
@include common-account
EOF
cat "$KDE_FP"

echo
echo "Done. Lock the screen (Meta+L) and look at the camera."
