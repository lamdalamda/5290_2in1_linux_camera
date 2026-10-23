#!/bin/bash
# Report the state of every piece the front camera needs. No root required.

ok() { printf '  [ok]   %s\n' "$1"; }
bad() { printf '  [FAIL] %s\n' "$1"; }

check() {
	if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi
}

echo "Kernel $(uname -r)"
check "boot parameter acpi_enforce_resources=lax" \
	"grep -q acpi_enforce_resources=lax /proc/cmdline"
check "patched TPS68470 module is the one modprobe picks" \
	"modinfo -n intel_skl_int3472_tps68470 | grep -q updates/dkms"
check "TPS68470 PMIC bound" \
	"[ -e /sys/bus/i2c/devices/i2c-INT3472:05/driver ]"
check "TPS68470 regulators registered" \
	"grep -qx VSIO /sys/class/regulator/regulator.*/name"
check "I2C4 controller (INT3446) probed" \
	"[ -e /sys/bus/acpi/devices/INT3446:00/physical_node/driver ]"
check "OV5670 sensor bound to ov5670 driver" \
	"[ \"\$(basename \"\$(readlink -f /sys/bus/i2c/devices/i2c-INT3479:00/driver)\")\" = ov5670 ]"
check "libcamera lists the front camera (LNK0)" \
	"cam -l 2>/dev/null | grep -q LNK0"
check "PipeWire has an ov5670 node" \
	"wpctl status | grep -q ov5670"

echo
echo "Kernel messages:"
journalctl -k -b --no-pager 2>/dev/null |
	grep -E 'TPS68470|No board-data|INT3446|Found supported sensor' | sed 's/^/  /'
