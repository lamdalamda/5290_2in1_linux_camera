# Battery charge limit switch (60% / 100%)

The same setting Dell Power Manager changes on Windows. The `dell-laptop`
driver exposes it in `/sys/class/power_supply/BAT0/`, and the BIOS stores it,
so it survives reboots and other operating systems.

| Mode | `charge_types` | Behaviour |
|---|---|---|
| 60 | `Custom`, start 50, end 60 | starts charging below 50%, stops at 60% |
| 100 | `Standard` | charges to 100% |

The thresholds only apply in `Custom` mode. KDE's own "charge limit" setting
writes the thresholds but leaves the mode alone, so on this laptop (default
`Adaptive`) it has no effect.

## Install

```bash
sudo ./battery/install.sh
```

Installs:

- `/usr/local/libexec/battery-limit-helper`: root helper, accepts only `60` or `100`
- `/usr/local/bin/battery-limit`: `battery-limit [60|100|toggle]`, prints the
  state and shows a notification
- `/usr/share/polkit-1/actions/org.local.battery-limit.policy`: lets the user
  at the machine run the helper through `pkexec` without a password (remote
  sessions still need one)
- `/usr/share/applications/battery-limit.desktop`: app menu entry that toggles;
  right-click for "充到 60%" / "充到 100%". It can be pinned to the panel.

## Undo

```bash
sudo rm /usr/local/bin/battery-limit /usr/local/libexec/battery-limit-helper \
  /usr/share/polkit-1/actions/org.local.battery-limit.policy \
  /usr/share/applications/battery-limit.desktop
```

The BIOS keeps the last mode. Set `100` first if you want full charging back.
