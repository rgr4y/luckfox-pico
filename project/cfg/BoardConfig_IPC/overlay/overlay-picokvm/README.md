# PicoKVM Rootfs Overlay

Files in this directory are merged into the rootfs during build via `RK_POST_OVERLAY`.

## Pre-built binaries (must be placed manually before build)

These are static/pre-compiled binaries not available in buildroot. Download or
cross-compile them for `armv7l` (ARM hard-float, uClibc-ng compatible where
applicable — most are static Go/Rust so libc doesn't matter).

### VPN tools → `usr/bin/`

| Binary | Source | Size |
|--------|--------|------|
| `cloudflared` | https://github.com/cloudflare/cloudflared/releases | 24.6M |
| `tailscale` | https://pkgs.tailscale.com/stable/ | 19.4M |
| `tailscaled` | https://pkgs.tailscale.com/stable/ | 23.2M |
| `frpc` | https://github.com/fatedier/frp/releases | 13.2M |
| `zerotier-one` | https://github.com/zerotier/ZeroTierOne/releases | 1.7M |
| `easytier-cli` | https://github.com/EasyTier/EasyTier/releases | 1.5M |
| `easytier-core` | https://github.com/EasyTier/EasyTier/releases | 4.2M |
| `vnt-cli` | https://github.com/lbl8603/vnt/releases | 2.6M |
| `vn-link-cli` | https://github.com/lbl8603/vnt/releases | 2.7M |

### KVM-specific → `usr/bin/`

| Binary | Source | Size |
|--------|--------|------|
| `kvm_video` | https://github.com/luckfox-eng29/kvm_video (cross-compile) | 116K |
| `kvm_display` | https://github.com/luckfox-eng29/kvm_video (cross-compile) | 1.5M |
| `rk_ota` | From PicoKVM stock rootfs (no public source) | 39K |

### RKNN model → `usr/model/`

| File | Source | Size |
|------|--------|------|
| `yolov5.rknn` | From PicoKVM stock rootfs | 7.5M |
| `coco_80_labels_list.txt` | From PicoKVM stock rootfs | 621B |

### Kernel modules → `oem/usr/ko/`

The stock `insmod_ko.sh` and kernel modules are built by the SDK (`./build.sh driver`).
PicoKVM-specific additions:

| Module | Purpose |
|--------|---------|
| `tc358743.ko` | Toshiba TC358743 HDMI-to-CSI bridge driver |
| `tc35874x.ko` | TC35874x family driver (alternate) |

These are built from the kernel source with `CONFIG_VIDEO_TC358743=m` enabled
(see `rv1106-kvm.config` kernel defconfig fragment).

## What buildroot provides (via luckfox_pico_kvm_defconfig)

bash, openssh, curl, nano, htop, socat, ffmpeg, gdb, iperf, dialog, evtest,
tree, lsof, ppp, avahi, collectd, fuse3, wireguard-tools, alsa-utils,
opus-tools, and all standard SDK packages.
