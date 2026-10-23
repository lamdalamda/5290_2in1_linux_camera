#!/bin/bash
# Record 3 s from the IR camera and print one mark per frame:
# '#' = emitter lit, '.' = dark. A working emitter alternates # and .
# Needs ffmpeg.
set -euo pipefail

dev=$(ls /dev/v4l/by-id/*Integrated_Webcam_HD*-video-index0 2>/dev/null | head -1 || true)
if [ -z "$dev" ]; then
	echo "IR camera not found under /dev/v4l/by-id" >&2
	exit 1
fi
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

ffmpeg -hide_banner -loglevel error -y -f v4l2 -i "$dev" -t 3 "$tmp/f%03d.png"
for f in "$tmp"/f*.png; do
	ffmpeg -hide_banner -i "$f" -vf signalstats,metadata=print -f null - 2>&1 |
		grep -oE 'YAVG=[0-9]+' | cut -d= -f2
done | awk '{ printf "%s", ($1 > 60 ? "#" : "."); n++; lit += ($1 > 60) }
	END { printf "\n%d frames, %d lit\n", n, lit }'
