# Face unlock with Howdy (lock screen only)

Status: working on Kubuntu 26.04, Plasma 6.6, Howdy 3.0.0 (git 2025-10-03)
from `ppa:ubuntuhandbook1/howdy`. The KDE lock screen unlocks by face in a
few seconds. The password field keeps working at the same time.

Scope on purpose:

| Where | Face | Why |
|---|---|---|
| KDE lock screen | yes | the point of this setup |
| SDDM login after boot | no | KWallet (Wi-Fi and browser secrets) only unlocks with the login password |
| sudo | no (opt-in with `--sudo`) | any program you run could get root while you sit in front of the camera |
| su, polkit, everything else | no | Howdy is kept out of `common-auth` |

## Install

```bash
sudo ./scripts/howdy/install.sh
```

- Adds the PPA and installs `howdy`, `python3-dlib` and `dlib-models`.
- The package's postinst runs `pam-auth-update --package` with a profile that
  is on by default, which puts Howdy in `/etc/pam.d/common-auth` and so in
  every login, including SDDM. The script turns that profile off right away
  (`pam-auth-update --disable howdy`) and checks `common-auth`.
- Sets `device_path` in `/etc/howdy/config.ini` to the IR camera's
  `/dev/v4l/by-id/...-video-index0` path. The `/dev/videoN` number changes
  between boots on this laptop. The original config is kept as
  `config.ini.orig`.

The default `dark_threshold = 60` already skips the dark half of the frames
(the emitter only lights every other frame, see [ir-camera.md](ir-camera.md)).

## Enroll and test

```bash
sudo howdy add
```

Look at the camera until it finishes. The model is saved under
`/usr/share/dlib/<user>.dat` by this package. A second model without glasses
can help.

Test recognition without touching PAM (exit code 0 means recognised):

```bash
sudo /usr/bin/python3 /usr/lib/howdy/compare.py "$USER"; echo $?
```

## Enable on the lock screen

```bash
sudo ./scripts/howdy/enable-pam.sh
```

The Plasma 6 lock screen (`kscreenlocker_greet`) runs three PAM services:
`kde` for the password field, and `kde-fingerprint` and `kde-smartcard` as
background, non-interactive authenticators. This laptop's fingerprint reader
does not work, so `kde-fingerprint` is free. The script writes:

```
auth       sufficient   /usr/lib/security/howdy/pam_howdy.so
auth       required     pam_deny.so
@include common-account
```

to `/etc/pam.d/kde-fingerprint`. Lock with Meta+L and look at the camera.
`journalctl -b | grep pam_howdy` shows `Login approved` on success.

## Undo

```bash
sudo ./scripts/howdy/disable-pam.sh
sudo apt purge howdy
sudo add-apt-repository --remove ppa:ubuntuhandbook1/howdy
```
