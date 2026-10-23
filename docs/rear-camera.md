# Rear camera (OV8858): plan

Status: not done. Notes and a tested starting point.

## What is already there

With the front-camera fix installed, the PMIC powers up and the kernel creates
the rear sensor's I2C client `i2c-INT3477:00` on I2C2, behind the TPS68470's
I2C passthrough. No driver binds to it.

## What is missing

| Piece | Module | Fix |
|---|---|---|
| PMIC rails, GPIOs and 19.2 MHz clock for `INT3477` | `intel_skl_int3472_tps68470` | 5290-specific board data covering both sensors, static clock consumers, GNVS clock fix |
| CSI-2 graph for `INT3477` | `ipu-bridge` | Sensor entry for `INT3477`, 360 MHz link |
| ACPI match for `INT3477`, `vsio` supply | `ov8858` | Add ACPI ID and supply name |
| Focus motor | `dw9714` | Already in-tree; optional sleep fix |

The 7212 board data used for the front camera only describes `INT3479`, so the
front-camera DMI entry has to be replaced by full 5290 board data.

All of these are loadable modules in the Ubuntu kernel
(`CONFIG_INTEL_SKL_INT3472=m`, `CONFIG_IPU_BRIDGE=m`, `CONFIG_VIDEO_OV8858=m`,
`CONFIG_MFD_INTEL_LPSS_ACPI=m`), so the same DKMS approach works. No custom
kernel is needed.

## Tested starting point

All 13 patches from
[vitovt/dell-5290-camera-kernel](https://github.com/vitovt/dell-5290-camera-kernel)
`patches/series` apply cleanly to upstream v7.0.14. The affected modules build
out of tree against `7.0.0-38-generic` headers:

- `intel_skl_int3472_tps68470.ko` (patches 0001, 0101, 0102, 0902-0904)
- `ipu-bridge.ko` (0103)
- `ov8858.ko` (0104, 0201)
- `ov5670.ko` (0201, 0900, 0901)
- `dw9714.ko` (0200)
- `intel-lpss-acpi.ko` (0100, would replace `acpi_enforce_resources=lax`)

Nothing has been installed or loaded from this set yet.

## Proposed steps

1. Package the modules above as DKMS version 2.0 of this repo, with the front
   camera still working at every step.
2. Test-load on a running system first (like the front-camera test): swap
   modules with `rmmod`/`insmod`, check the kernel log, and reboot to undo.
3. Install with DKMS and reboot. Check `cam -l` for a second IPU3 camera on
   LNK1 and capture a frame.
4. Optionally switch from the boot parameter to the `intel-lpss-acpi` quirk.
5. Test suspend and resume with both cameras.

## Risks to keep in mind

- Patch 0101 writes three bytes of the BIOS GNVS area in RAM at probe time to
  correct the camera clock fields. This only lasts until the next boot.
- Wrong regulator data could feed a sensor the wrong voltage. The voltages in
  patch 0102 come from vitovt's working 5290 setup. Compare them with the
  upstream 5285 series before installing.
- IPU3 runs one camera pipeline at a time, so front and rear cannot stream
  together.
