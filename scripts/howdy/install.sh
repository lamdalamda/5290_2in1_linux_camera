#!/bin/bash
# Install Howdy for the 5290 IR camera without turning it on anywhere.
#
#  1. Add ppa:ubuntuhandbook1/howdy and install howdy (pulls python3-dlib
#     and dlib-models from the same PPA)
#  2. Turn off the PAM profile the package enables by default. That profile
#     adds Howdy to common-auth, which would cover every login including SDDM.
#  3. Point Howdy at the IR camera by its stable /dev/v4l/by-id path
#
# Then enroll with `sudo howdy add` and run scripts/howdy/enable-pam.sh.
set -euo pipefail

CONFIG=/etc/howdy/config.ini

if fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
	echo "Another apt/dpkg process holds the package lock:" >&2
	ps -o pid,stat,etime,cmd -p "$(fuser /var/lib/dpkg/lock-frontend 2>/dev/null | tr -s ' ' ',' | sed 's/^,//')" >&2 || true
	echo "Let it finish (or resume it with fg if it shows state T), then rerun." >&2
	exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
	echo "Run with sudo" >&2
	exit 1
fi

dev=$(ls /dev/v4l/by-id/*Integrated_Webcam_HD*-video-index0 2>/dev/null | head -1 || true)
if [ -z "$dev" ]; then
	echo "IR camera not found under /dev/v4l/by-id" >&2
	exit 1
fi

echo "== Install"
add-apt-repository -y ppa:ubuntuhandbook1/howdy
apt-get install -y howdy

echo "== Keep Howdy out of common-auth"
pam-auth-update --disable howdy
if grep -q howdy /etc/pam.d/common-auth; then
	echo "Howdy is still in /etc/pam.d/common-auth. Stopping." >&2
	exit 1
fi

echo "== Configure"
[ -e "$CONFIG.orig" ] || cp "$CONFIG" "$CONFIG.orig"
sed -i "s|^device_path = .*|device_path = $dev|" "$CONFIG"
grep -E '^(device_path|dark_threshold|certainty|timeout|abort_if_lid_closed) ' "$CONFIG"

echo
echo "Done. Enroll your face with: sudo howdy add"
