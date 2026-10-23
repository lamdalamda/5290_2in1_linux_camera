# Front IR camera (Windows Hello)

Status: **works out of the box.** The IR emitter strobes on every other frame
as soon as the camera streams. No emitter tool is needed.

## Hardware

- USB device `0bda:551a` "Integrated_Webcam_HD" (Realtek), driver `uvcvideo`.
- Device node changes between boots (it was `/dev/video0`, now `/dev/video14`
  once the IPU3 nodes exist). Use the stable path
  `/dev/v4l/by-id/usb-*_Integrated_Webcam_HD_*-video-index0`.
- One format: YUYV 340x340 at 30 fps. Frames are greyscale (U and V are
  constant 128).

## The emitter strobes on alternate frames

```bash
./scripts/ir-strobe-test.sh
```

```
.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#.#
90 frames, 45 lit
```

Lit frames have a mean luma of about 95/255 (peaks 235) and show the face
clearly. Dark frames are about 35/255. Windows Hello cameras work this way:
the driver subtracts the dark frame from the lit one to remove ambient light.

Lesson learned: the first test grabbed a single frame (frame 20). Every
even-numbered frame is a dark one, so that test wrongly suggested the emitter
was off. Look at a sequence of frames, not one.

Face recognition tools must skip the dark frames. Howdy does this with its
`dark_threshold` setting.

## Realtek extension unit (for reference)

The camera has a Realtek register-access extension unit, GUID
`{1229a78c-47b4-4094-b0ce-db07386fb938}`, unit 10, with an address selector
(0x0a) and a data selector (0x0b). It uses the same protocol as the Dell
Realtek camera documented in
[SeeleVolleri/research_0jcxg0](https://github.com/SeeleVolleri/research_0jcxg0).
`scripts/rtk-ir.py probe` reads its identification registers without writing
data:

| Register | This camera | Camera in the research |
|---|---|---|
| `0x0a` initial value | `00 08 00 bb bb bb bb bb` | same |
| `d000` vendor | `REALSIL` | `REALSIL` |
| `cd00` device ID | `da 0b 47 58 9c 00 11 c0` | `da 0b 75 58 22 42 10 10` |
| `cd02` firmware date | `10/05/17` | `08/18/15` |
| `9f00` IR mode | read refused (EACCES) | never read by Windows |

On the research camera (a combined RGB + IR module) writing `0x01` to `0x9f00`
switches to IR mode. This camera is IR only, so it does not need that.

Avoid brute-force emitter tools such as
[linux-enable-ir-emitter](https://github.com/EmixamPP/linux-enable-ir-emitter)
on this camera. They try many values on the camera's controls, and on a
register-access unit like this one that means writing to arbitrary chip
registers.

## Face login options considered

| Tool | Uses | Notes |
|---|---|---|
| [Howdy](https://github.com/boltgolt/howdy) | IR frames for recognition | Most used; unofficial PPA for 26.04; not updated for over a year; skips dark frames via `dark_threshold` |
| [Biopass](https://github.com/TickLabVN/biopass) | RGB for recognition, IR for anti-spoofing | GUI, `.deb` for 26.04+; uses the front colour camera, which now works |
| [Visage](https://github.com/sovren-software/visage) | IR | Author says not ready for daily use |
| Gaze | Webcam | GNOME-focused, can be fooled by a photo |

All of these are weaker than a password. Keep password fallback, and use face
login for the lock screen and `sudo`, not the SDDM login. A face login at SDDM
cannot unlock KWallet, which needs the password.
