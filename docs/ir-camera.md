# Front IR camera (Windows Hello)

Status: investigated, emitter not configured yet.

## Hardware

- USB device `0bda:551a` "Integrated_Webcam_HD" (Realtek), driver `uvcvideo`.
- Exposes `/dev/video0` (capture) and `/dev/video1` (metadata).
- One format: YUYV 340x340. Frames are greyscale (U and V are constant 128).
- Extension units in the USB descriptor:
  - unit 12, GUID `{45b5da73-23c1-4a3d-a368-610f078c4397}`, no controls
  - unit 10, GUID `{1229a78c-47b4-4094-b0ce-db07386fb938}`, 2 controls
    (selectors 10 and 11). The emitter switch is probably here.
- No Microsoft camera extension unit, so the standard IR torch control is not
  available.

A frame captured on Linux is almost black (mean luma about 36/255): the sensor
works, but the IR emitter stays off. The faint red glow next to the lens in
Windows Hello is the 850 nm IR emitter. Linux has no driver that turns it on.

## Turning the emitter on

[linux-enable-ir-emitter](https://github.com/EmixamPP/linux-enable-ir-emitter)
finds the UVC control that switches the emitter on, by trying values while you
watch for blinking. Version 6.1.2 (stable) is installed on the test machine in
`/usr/local/bin`. `configure` has not been run, and the systemd service is not
enabled.

Risk notes from the author's docs and issues:

- Reported broken cameras came from interrupting a run with Ctrl+C
  ([#177](https://github.com/EmixamPP/linux-enable-ir-emitter/issues/177), fixed
  since), from configuring the wrong camera
  ([#190](https://github.com/EmixamPP/linux-enable-ir-emitter/issues/190)), or
  from Sunplus cameras. This camera is Realtek, and the colour cameras are not
  USB, so the tool cannot pick them by mistake.
- The author says such cameras are usually not physically damaged; the
  firmware is left in a wrong state. A full shutdown with the power removed
  recovered one case
  ([#70](https://github.com/EmixamPP/linux-enable-ir-emitter/issues/70)).
- Configurations live in `/etc/linux-enable-ir-emitter/`. Deleting one resets
  the camera to default on the next sleep, reboot or shutdown.

Plan when picking this up again:

```bash
sudo linux-enable-ir-emitter --device /dev/video0 configure
```

Then answer Y/N while watching the emitter (a phone camera shows IR light
better than the eye), and enable the service only after it works:

```bash
sudo systemctl enable --now linux-enable-ir-emitter
```

## Face login options considered

| Tool | Uses | Notes |
|---|---|---|
| [Howdy](https://github.com/boltgolt/howdy) | IR frames for recognition | Most used; unofficial PPA for 26.04; not updated for over a year |
| [Biopass](https://github.com/TickLabVN/biopass) | RGB for recognition, IR for anti-spoofing | GUI, `.deb` for 26.04+; needs the colour camera, now working |
| [Visage](https://github.com/sovren-software/visage) | IR, own emitter control | Author says not ready for daily use |
| Gaze | Webcam | GNOME-focused, can be fooled by a photo |

All of these are weaker than a password. Keep password fallback, and use face
login for the lock screen and `sudo`, not the SDDM login. A face login at SDDM
cannot unlock KWallet, which needs the password.
