#!/bin/bash
# Grab one 1280x720 frame from the front camera and save it as a JPEG.
# Usage: scripts/capture-test.sh [output.jpg]
# Needs libcamera-tools (cam) and ffmpeg.
set -euo pipefail

out="${1:-front-camera-test.jpg}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

camera=$(cam -l 2>/dev/null | grep -oE '\\_SB_\.PCI0\.LNK0' | head -1 || true)
if [ -z "$camera" ]; then
	echo "Front camera not found by libcamera. Run scripts/check.sh" >&2
	exit 1
fi

# Skip the first frames while auto-exposure settles.
cam -c "$camera" -C30 -s role=viewfinder,width=1280,height=720 \
	-F"$tmp/frame-#.bin" >/dev/null 2>&1
last=$(ls "$tmp"/frame-*.bin | sort | tail -1)
ffmpeg -hide_banner -loglevel error -y -f rawvideo -pix_fmt nv12 \
	-s 1280x720 -i "$last" -frames:v 1 "$out"
echo "Saved $out"
