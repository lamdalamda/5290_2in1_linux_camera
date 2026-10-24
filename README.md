# Dell Latitude 5290 2-in-1: front camera on Linux

[中文说明](README.zh-CN.md)

This repository makes the **front colour camera (OmniVision OV5670)** of the
Dell Latitude 5290 2-in-1 work on a stock Ubuntu kernel. It does not need a
custom kernel. It installs one patched kernel module through DKMS and adds one
boot parameter.

Tested on Kubuntu 26.04 (KDE Plasma 6, Wayland), kernel `7.0.0-38-generic`
(upstream 7.0.14), libcamera 0.7.0. The camera delivers 1280x720 NV12 at
30 fps through libcamera and shows up in PipeWire, so browsers and video-call
apps can use it.

| Camera | Hardware | Status |
|---|---|---|
| Front colour | OV5670 on IPU3 (ACPI `INT3479`, LNK0) | Works with this repo |
| Rear colour | OV8858 on IPU3 (ACPI `INT3477`, LNK1) | Not yet. See [docs/rear-camera.md](docs/rear-camera.md) |
| Front IR (Windows Hello) | Realtek USB UVC `0bda:551a`, 340x340 grey | Works out of the box; the emitter strobes on every other frame. See [docs/ir-camera.md](docs/ir-camera.md) |
| Face unlock | Howdy on the IR camera | Lock screen unlocks by face. See [docs/howdy.md](docs/howdy.md) |
| Battery charge limit | `dell-laptop` driver, stored in BIOS | 60% / 100% switch in the app menu. See [battery/](battery/) |

## Why the front camera does not work out of the box

The sensor driver (`ov5670`) and the IPU3 drivers are already in the kernel.
Two pieces of board glue are missing:

1. **The camera PMIC has no board data for this laptop.** The TPS68470 PMIC
   powers the sensor. Its driver needs a table of regulator and GPIO wiring for
   each laptop model, and the 5290 2-in-1 is not in that table. At boot it
   logs `int3472-tps68470 i2c-INT3472:05: error -ENODEV: No board-data found for
   this model`, and the sensor never gets power. The 5290 2-in-1 uses the same
   wiring as the Dell Latitude 7212 Rugged Extreme Tablet, which is already in
   the table. The fix is a 7-line DMI entry that points the 5290 at the 7212
   data: [patches/0001-int3472-tps68470-add-Dell-Latitude-5290-2-in-1.patch](patches/0001-int3472-tps68470-add-Dell-Latitude-5290-2-in-1.patch).
2. **The sensor's I2C bus is blocked by a BIOS resource conflict.** The BIOS
   claims the I2C4 controller's registers (`INT3446`) in an ACPI OperationRegion
   called GEXP, so `intel-lpss` refuses to probe it
   (`probe with driver intel-lpss failed with error -16`). Without I2C4 the
   kernel cannot reach the OV5670. The boot parameter
   `acpi_enforce_resources=lax` lets the driver probe anyway.

## Install

```bash
sudo apt install build-essential dkms libcamera-tools libcamera-ipa gstreamer1.0-libcamera pipewire-libcamera
```

```bash
sudo ./scripts/install.sh --show-grub-menu
```

`install.sh` does three things:

- Copies [dkms/dell5290-tps68470-1.0](dkms/dell5290-tps68470-1.0) to
  `/usr/src` and installs it with DKMS. The module lands in
  `/lib/modules/$(uname -r)/updates/dkms/` and takes priority over the stock
  module. DKMS rebuilds it on kernel upgrades.
- Backs up `/etc/default/grub` to `/etc/default/grub.bak-dell5290`, appends
  `acpi_enforce_resources=lax` to `GRUB_CMDLINE_LINUX_DEFAULT`, and runs
  `update-grub`.
- With `--show-grub-menu`, also sets `GRUB_TIMEOUT_STYLE=menu` and
  `GRUB_TIMEOUT=5`, so you can pick the previous kernel or edit the command
  line if a boot goes wrong. Ubuntu hides the menu by default.

Then reboot.

## Check

```bash
./scripts/check.sh
```

Expected output on a working system:

```
  [ok]   boot parameter acpi_enforce_resources=lax
  [ok]   patched TPS68470 module is the one modprobe picks
  [ok]   TPS68470 PMIC bound
  [ok]   TPS68470 regulators registered
  [ok]   I2C4 controller (INT3446) probed
  [ok]   OV5670 sensor bound to ov5670 driver
  [ok]   libcamera lists the front camera (LNK0)
  [ok]   PipeWire has an ov5670 node
```

Take a test photo (needs `ffmpeg`):

```bash
./scripts/capture-test.sh
```

## Using the camera in apps

- Apps see two front cameras. `ov5670` is the colour camera.
  `Integrated_Webcam_HD` is the IR camera, which shows a flickering grey image.
- Firefox uses the PipeWire camera portal by default on recent versions.
- Chrome and Chromium need `chrome://flags/#enable-webrtc-pipewire-camera`
  enabled.

## Uninstall

```bash
sudo ./scripts/uninstall.sh
```

This removes the DKMS module (DKMS restores the stock module), restores the
GRUB backup, and runs `update-grub`. Reboot afterwards.

## Known limitations

- **Colours look washed out.** libcamera has no tuning file for the OV5670 on
  IPU3 and falls back to `uncalibrated.yaml`.
- **`acpi_enforce_resources=lax` applies to the whole system.** On this laptop
  the BIOS only uses the GEXP region for the fingerprint reader and tablet-mode
  detection. Touchscreen, Wacom pen, and the tablet-mode switch
  (`Intel Virtual Switches`) were checked and still work. A cleaner fix is a
  DMI quirk in `intel-lpss-acpi` (see vitovt's patch `0100` below), which
  would remove the need for the boot parameter.
- **The module source is from upstream 7.0.14.** DKMS rebuilds it for new
  kernels. If a much newer kernel changes the int3472 driver, rebuild the
  DKMS source from that kernel's `drivers/platform/x86/intel/int3472/` and
  re-apply the patch. Once a kernel ships the 5290 DMI entry itself, uninstall
  this module and keep only the boot parameter.
- **Suspend and hibernate have not been tested.** vitovt reports I2C errors from
  the sensors after resume and carries extra patches for them.
- Kernel log shows `loading out-of-tree module taints kernel`. This is
  expected for any DKMS module. Secure Boot is disabled on the test machine. With
  Secure Boot on, DKMS signs the module with the machine's MOK key, which has to
  be enrolled once.

## Credits

- **Dan Scally** and **Hans de Goede** wrote the upstream `int3472-tps68470` and
  `ipu-bridge` drivers and found the Dell 7212 wiring.
- **[jelsco/latitude-5290-camera](https://github.com/jelsco/latitude-5290-camera)**
  found that the 5290 2-in-1 reuses the 7212 board data and needs
  `acpi_enforce_resources=lax`. This repo follows the same approach.
- **[Arch Linux forum thread](https://bbs.archlinux.org/viewtopic.php?id=314884)**:
  the same DMI patch confirmed on kernel 7.2.4.
- **[vitovt/dell-5290-camera-kernel](https://github.com/vitovt/dell-5290-camera-kernel)**:
  a full custom-kernel build with patches for both cameras and for
  suspend/hibernate.
- **Thierry Chatard**:
  [upstream patch series for the Latitude 5285 2-in-1](https://lkml.iu.edu/2603.3/02219.html)
  (front + rear, same platform).

## License

GPL-2.0, as for the kernel files the module is derived from. See [LICENSE](LICENSE).
