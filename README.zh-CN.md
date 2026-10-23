# Dell Latitude 5290 二合一：在 Linux 上启用前置摄像头

[English](README.md)

这个仓库让 Dell Latitude 5290 二合一的**前置彩色摄像头（OmniVision OV5670）**在 Ubuntu 原版内核上可用。不用编译自定义内核，只需用 DKMS 装一个打过补丁的内核模块，再加一个启动参数。

测试环境：Kubuntu 26.04（KDE Plasma 6，Wayland），内核 `7.0.0-38-generic`（对应上游 7.0.14），libcamera 0.7.0。摄像头通过 libcamera 输出 1280×720 NV12、30fps，在 PipeWire 中可见，浏览器和视频会议软件都能使用。

| 摄像头 | 硬件 | 状态 |
|---|---|---|
| 前置彩色 | IPU3 上的 OV5670（ACPI `INT3479`，LNK0） | 用本仓库即可工作 |
| 后置彩色 | IPU3 上的 OV8858（ACPI `INT3477`，LNK1） | 尚未完成，见 [docs/rear-camera.md](docs/rear-camera.md) |
| 前置红外（Windows Hello） | Realtek USB UVC `0bda:551a`，340×340 灰度 | 开箱即用，补光灯每隔一帧闪一次，见 [docs/ir-camera.md](docs/ir-camera.md) |

## 为什么默认不工作

传感器驱动（`ov5670`）和 IPU3 驱动内核里本来就有，缺的是两处主板适配：

1. **供电芯片缺少这台电脑的板级数据。** 摄像头由 TPS68470 电源管理芯片供电，它的驱动需要一张“每个机型的稳压器和 GPIO 接法”表，而表里没有 5290 二合一。开机时会报 `No board-data found for this model`，传感器始终没有上电。5290 二合一的接法和表里已有的 Dell Latitude 7212 Rugged Extreme Tablet 完全相同，所以修复办法只是加 7 行 DMI 匹配，让 5290 沿用 7212 的数据：[patches/0001-int3472-tps68470-add-Dell-Latitude-5290-2-in-1.patch](patches/0001-int3472-tps68470-add-Dell-Latitude-5290-2-in-1.patch)。
2. **传感器所在的 I2C 总线被 BIOS 资源冲突挡住了。** BIOS 在名为 GEXP 的 ACPI 区域里占用了 I2C4 控制器（`INT3446`）的寄存器，`intel-lpss` 驱动因此拒绝加载（`probe with driver intel-lpss failed with error -16`）。没有 I2C4，内核就连不上 OV5670。启动参数 `acpi_enforce_resources=lax` 可以让驱动照常加载。

## 安装

```bash
sudo apt install build-essential dkms libcamera-tools libcamera-ipa gstreamer1.0-libcamera pipewire-libcamera
```

```bash
sudo ./scripts/install.sh --show-grub-menu
```

`install.sh` 会做这几件事：

- 把 [dkms/dell5290-tps68470-1.0](dkms/dell5290-tps68470-1.0) 复制到 `/usr/src`，用 DKMS 安装。模块装在 `/lib/modules/$(uname -r)/updates/dkms/`，优先级高于系统原有模块；内核升级时 DKMS 会自动重新编译。
- 把 `/etc/default/grub` 备份为 `/etc/default/grub.bak-dell5290`，在 `GRUB_CMDLINE_LINUX_DEFAULT` 末尾加上 `acpi_enforce_resources=lax`，然后运行 `update-grub`。
- 加上 `--show-grub-menu` 时，还会把开机菜单设为显示 5 秒（Ubuntu 默认隐藏菜单）。万一开机出问题，可以在菜单里选旧内核，或临时修改启动参数。

然后重启。

## 检查

```bash
./scripts/check.sh
```

正常的话 8 项都显示 `[ok]`。拍一张测试照片（需要 `ffmpeg`）：

```bash
./scripts/capture-test.sh
```

## 在软件里使用

- 软件里会看到两个前置摄像头：`ov5670` 是彩色摄像头；`Integrated_Webcam_HD` 是红外摄像头，画面是闪烁的灰度图。
- 新版 Firefox 默认通过 PipeWire 调用摄像头。
- Chrome / Chromium 需要在 `chrome://flags/#enable-webrtc-pipewire-camera` 里打开 PipeWire 摄像头支持。

## 卸载

```bash
sudo ./scripts/uninstall.sh
```

会删除 DKMS 模块（DKMS 会恢复系统原有模块）、还原 GRUB 备份并运行 `update-grub`。完成后重启。

## 已知限制

- **颜色偏淡。** libcamera 没有 OV5670 在 IPU3 上的调校文件，只能用通用的 `uncalibrated.yaml`。
- **`acpi_enforce_resources=lax` 对整个系统生效。** 这台电脑的 BIOS 只在指纹读取器和平板模式检测上使用 GEXP 区域。已确认触屏、Wacom 手写笔和平板模式开关（`Intel Virtual Switches`）都正常。更干净的做法是在 `intel-lpss-acpi` 里加 DMI 特例（见 vitovt 的 `0100` 补丁），这样就不需要启动参数。
- **模块源码来自上游 7.0.14。** DKMS 会为新内核重新编译。如果将来内核大改了 int3472 驱动，需要用新内核的 `drivers/platform/x86/intel/int3472/` 源码重新打补丁。等内核自带 5290 的 DMI 条目后，卸载这个模块，只保留启动参数即可。
- **还没测试睡眠和休眠。** vitovt 报告恢复后传感器会出现 I2C 错误，并为此准备了额外补丁。
- 内核日志会出现 `loading out-of-tree module taints kernel`，所有 DKMS 模块都会这样，属于正常现象。测试机关闭了 Secure Boot；如果开着 Secure Boot，DKMS 会用本机 MOK 密钥给模块签名，需要先登记一次密钥。

## 致谢

- **Dan Scally** 和 **Hans de Goede**：编写了上游 `int3472-tps68470` 和 `ipu-bridge` 驱动，并整理了 Dell 7212 的接法。
- **[jelsco/latitude-5290-camera](https://github.com/jelsco/latitude-5290-camera)**：发现 5290 二合一可以沿用 7212 的板级数据，并且需要 `acpi_enforce_resources=lax`。本仓库采用同样的思路。
- **[Arch Linux 论坛帖子](https://bbs.archlinux.org/viewtopic.php?id=314884)**：在 7.2.4 内核上验证了同样的 DMI 补丁。
- **[vitovt/dell-5290-camera-kernel](https://github.com/vitovt/dell-5290-camera-kernel)**：编译完整自定义内核的方案，包含前后摄像头以及睡眠/休眠的补丁。
- **Thierry Chatard**：为同平台的 Latitude 5285 二合一提交的[上游补丁系列](https://lkml.iu.edu/2603.3/02219.html)（前置 + 后置）。

## 许可证

GPL-2.0，与模块所源自的内核文件一致。见 [LICENSE](LICENSE)。
