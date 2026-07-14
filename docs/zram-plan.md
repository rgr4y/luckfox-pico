# zram swap for Luckfox Pico Pro Max (RV1106, SPI-NAND, 256MB)

Replace the SD-card swapfile with an in-RAM **zram** swap (zstd-compressed).
Faster than SD swap and eliminates swap-related flash wear on the SD card.

Board: `10.0.1.13` (ssh `root@`, no password). Kernel `5.10.160` Rockchip BSP.

---

## What this change is (read first — it's TWO parts)

zram needs a kernel driver **and** a userspace init script. They live in two
different flash partitions:

1. **Kernel** (`mtd3` "boot", FIT image) — adds `CONFIG_ZRAM`/`CONFIG_ZSMALLOC`
   builtin. This IS reflashed here (`boot-zram.img` → `/dev/mtd3`).
2. **Rootfs init scripts** (`mtd6` "rootfs", ubifs) — `S14zram` (creates the
   swap) and the `S15sdmount` edit (stops the SD swapfile). **We do NOT reflash
   the rootfs.** So these must be applied to the *live* rootfs by hand (it's a
   rw ubifs — steps below). They're also committed to the SDK overlay so a full
   image rebuild keeps them.

If you only flash the kernel and skip step 2, you get zram *capability* but no
swap is created at boot until the init script is present.

---

## SDK source changes already staged (survive an image rebuild)

| File | Change |
|---|---|
| `sysdrv/source/kernel/arch/arm/configs/luckfox_rv1106_linux_defconfig` | `+CONFIG_ZRAM=y`, `+CONFIG_ZSMALLOC=y` (after `CONFIG_BLK_DEV_RAM=y`). `CONFIG_CRYPTO_ZSTD=y` was already set. |
| `project/cfg/BoardConfig_IPC/overlay/overlay-luckfox-buildroot-init/etc/init.d/S14zram` | **new** — creates `/dev/zram0`, zstd, 384M disksize, mkswap+swapon, `vm.swappiness=150`. Idempotent, has stop. This overlay is active in the Pro Max board config. |
| `project/cfg/BoardConfig_IPC/overlay/overlay-luckfox-clean/etc/init.d/S15sdmount` | SD-swapfile `swapon` commented out; no longer forces `swappiness=10`. |

Defconfig diff:
```
 CONFIG_BLK_DEV_RAM=y
+CONFIG_ZRAM=y
+CONFIG_ZSMALLOC=y
 CONFIG_CDROM_PKTCDVD=y
```

### Compressor note (verified against this kernel tree)
This 5.10 tree's `drivers/block/zram/Kconfig` has **no `CONFIG_ZRAM_DEF_COMP_*`
choice** — zram `select`s `CRYPTO_LZO` as the builtin default and the compressor
is chosen at **runtime** via `/sys/block/zram0/comp_algorithm`. `S14zram` writes
`zstd` there (works because `CONFIG_CRYPTO_ZSTD=y` is already builtin) and falls
back to lzo if zstd isn't listed. No kernel `DEF_COMP` symbol was needed.

### swapon priority note (verified)
BusyBox `swapon` on this board has **no `-p`/priority flag** (`swapon [-a][-e]
[DEVICE]` only). So priority can't be set. Instead the SD swapfile is disabled
so zram is the *sole* swap and priority is moot. `S14zram` runs at S14 (before
S15sdmount) as belt-and-suspenders.

### Board-config caveat (VERIFIED against live board 10.0.1.13)
The live board is a **SPI-NAND Pro Max** build (`/proc/cmdline` mtdparts =
`...4M(boot)...` → mtd3="boot"; `root=ubi0:rootfs`). Its live `/etc/init.d/`
has **`S15sdmount`** (swaps `/mnt/sdcard/swapfile`, pri -2) + `S15optmount`.
It is NOT a picokvm build (picokvm ships `S25swap` on `/userdata/swapfile`
instead — not present here). So the SD-swap disable correctly belongs in the
`S15sdmount` path.

`S15sdmount` exists in the SDK only under `overlay-luckfox-clean`, and that
overlay is in `RK_POST_OVERLAY` **only for `..._Pico_Pro_Max_Clean-IPC.mk`** (the
board config that matches this build; the plain `..._Pico_Pro_Max-IPC.mk` does
not include it). `S14zram` was placed in `overlay-luckfox-buildroot-init`, which
is active in **both**, so zram applies regardless. Kernel defconfig + DTS are
identical between the two, so `boot-zram.img` is correct for either.

> Caveats worth knowing: `overlay-luckfox-clean/` is currently **untracked** in
> git (new). Its `S15sdmount` is a rewrite that differs from the live file
> (live md5 `b2bc641d…`, overlay `eabd03bd…`) — functionally equivalent (mount
> SD, /opt symlink, TUN, swap disabled) but restructured. When committing, add
> the whole overlay + the `_Clean-IPC.mk` board config together. Step 4 below
> also hand-applies to the live rootfs, so the live board is covered either way.

---

## Kernel build (how boot-zram.img was produced)

Built in an OrbStack `--platform linux/amd64 ubuntu:24.04` container (the x86-64
SDK toolchain can't run natively on the arm64 Mac; runs under Rosetta). The
container `lfbuild` has the SDK bind-mounted at `/sdk` (virtiofs) and a
case-sensitive scratch tree at `/build`.

**Case-sensitivity gotcha:** the SDK checkout lives on a case-**insensitive**
Mac volume. The kernel has case-colliding files (`Documentation/Kbuild` file vs
`Documentation/kbuild/` dir; netfilter `xt_MARK.h`/`xt_mark.h`,
`xt_DSCP`/`xt_dscp`, `xt_CONNMARK`, `xt_RATEEST`, `xt_TCPMSS`, `ipt_ECN`,
`ipt_TTL`, `ip6t_HL`, and the matching `.c`) that get corrupted on disk, and
those netfilter targets are built `=y`. So the build pulls **pristine blobs from
git** (`git archive HEAD sysdrv/source/kernel`) into the case-sensitive `/build`
path in the container, applies the edited defconfig, and builds there.

> These netfilter files show as modified in `git status` on the Mac — that's the
> case-collision corruption of the working tree, NOT an intended change. Do not
> commit them. The build sidesteps them via `git archive` (pristine from HEAD).

> **Going forward:** move the SDK to the case-sensitive NVMe at
> `/Volumes/990Pro` (verified case-sensitive APFS) and this whole dance goes
> away — normal `./build.sh kernel` will just work.

**The real FIT-pack blocker (verified):** the kernel compiles fine and produces
`zImage` + `resource.img`, but the final `boot.img` (FIT) pack shells out to
`dtc`. If `dtc` is not on PATH, `mkimage` writes an empty `boot.img.tmp` and dies
with `Can't read boot.img.tmp: Invalid argument` — the misleading error that
stalled the first attempt. Fix: put the kernel's own freshly-built
`scripts/dtc/` on PATH before the pack step, and use the **rkbin** mkimage
(`sysdrv/source/uboot/rkbin/tools/mkimage`, the Rockchip-patched 2017.09 that the
SDK itself uses), not a plain u-boot mkimage.

Build commands (verified working — reproducibility):
```sh
# in amd64 container (ubuntu:24.04, deps: build-essential bison flex bc
# libssl-dev python-is-python3 git cpio rsync file):
rm -rf /build && mkdir -p /build
git -C /sdk config --global --add safe.directory /sdk
git -C /sdk archive HEAD sysdrv/source/kernel | tar -x -C /build
cp /sdk/sysdrv/source/kernel/arch/arm/configs/luckfox_rv1106_linux_defconfig \
   /build/sysdrv/source/kernel/arch/arm/configs/            # edited one (ZRAM)
cp /sdk/sysdrv/source/kernel/scripts/resource_tool \
   /build/sysdrv/source/kernel/scripts/                     # prebuilt amd64

cd /build/sysdrv/source/kernel
export ARCH=arm CROSS_COMPILE=arm-rockchip830-linux-uclibcgnueabihf-
export PATH=/sdk/tools/linux/toolchain/arm-rockchip830-linux-uclibcgnueabihf/bin:$PATH
make mrproper
make luckfox_rv1106_linux_defconfig
grep -E 'CONFIG_ZRAM|CONFIG_ZSMALLOC|CONFIG_CRYPTO_ZSTD|CONFIG_CRYPTO_LZO' .config
# compiles zImage + resource.img + builds scripts/dtc/dtc:
make rv1106g-luckfox-pico-pro-max.img BOOT_ITS=$PWD/boot.its -j"$(nproc)"

# ^ that img target's FIT pack fails if dtc isn't found. Run it explicitly with
#   dtc on PATH + the rkbin mkimage (this is what actually produced the image):
export PATH=/build/sysdrv/source/kernel/scripts/dtc:$PATH
cd out            # boot.its + fdt/kernel/resource live here after the make above
/sdk/sysdrv/source/uboot/rkbin/tools/mkimage -E -p 0x800 -f boot.its boot.img
cp -v boot.img /sdk/boot-zram.img
```

Output: **`/Users/rob/workspace/luckfox/luckfox-pico/boot-zram.img`** — 3,731,968
bytes (~3.56 MiB, fits the 4 MiB mtd3). FIT image (`d00dfeed` magic), external
data (`-E -p 0x800`), sha256 hash nodes, signature node present but unsigned —
identical format/flags to the current `/dev/mtd3` (u-boot does not enforce
verified boot here). See the header-match check below.

---

## FLASH PROCEDURE (run on the board when ready)

### 0. Sanity: confirm image format matches current mtd3 (already verified)
```sh
# on the Mac
hexdump -C boot-zram.img | head -1        # d0 0d fe ed 00 00 06 00 00 00 00 58 ...
# on the board
dd if=/dev/mtd3 bs=1 count=64 2>/dev/null | hexdump -C | head -1
#                                           d0 0d fe ed 00 00 06 00 00 00 00 48 ...
```
Both are FIT (`d0 0d fe ed`), identical totalsize `0x600` (external data via
`-E`), identical version + `size_dt_strings` (0x3f4). The `off_dt_struct` byte
(0x58 vs 0x48) differs only by per-build tree/timestamp variance — u-boot parses
FIT by structure, not fixed offset. Format confirmed compatible.
Size 3.56 MiB <= 4 MiB (mtd3 = 0x400000). OK.

### 1. Back up the current kernel partition FIRST (rollback safety)
```sh
# on the board
dd if=/dev/mtd3 of=/mnt/sdcard/mtd3-boot.backup bs=128k
ls -la /mnt/sdcard/mtd3-boot.backup      # ~4M
```

### 2. Copy the new image to the board
```sh
# on the Mac
scp boot-zram.img root@10.0.1.13:/mnt/sdcard/boot-zram.img
```

### 3. Flash mtd3
```sh
# on the board
flashcp -v /mnt/sdcard/boot-zram.img /dev/mtd3
```

### 4. Apply the rootfs init scripts to the LIVE rootfs (rootfs is NOT reflashed)
```sh
# on the Mac
scp project/cfg/BoardConfig_IPC/overlay/overlay-luckfox-buildroot-init/etc/init.d/S14zram \
    root@10.0.1.13:/etc/init.d/S14zram
# on the board
chmod 755 /etc/init.d/S14zram
# disable the SD swapfile in the live S15sdmount (comment the two lines):
sed -i '/swapon .*\/mnt\/sdcard\/swapfile/ s/^/#/' /etc/init.d/S15sdmount
sed -i '/vm\.swappiness=10/ s/^/#/'                /etc/init.d/S15sdmount
# and turn off the currently-active SD swap now (no reboot needed to stop it):
swapoff /mnt/sdcard/swapfile 2>/dev/null
```

### 5. Reboot
```sh
reboot
```

---

## VERIFICATION (after reboot)

```sh
dmesg | grep -i zram
#  expect: zram: Added device: zram0

ls /sys/class/zram-control          # exists => driver builtin & live
cat /sys/block/zram0/comp_algorithm # expect: ... [zstd] ...
cat /sys/block/zram0/disksize       # expect: 402653184  (384M)

cat /proc/swaps
#  expect a line: /dev/zram0   partition   393216   0   ...
#  and NO /mnt/sdcard/swapfile line

free -m                             # Swap total ~384

# confirm SD swapfile is no longer active:
grep swapfile /proc/swaps && echo "STILL ON - fix S15sdmount" || echo "SD swap off, good"
```
(`zramctl` is NOT installed on this busybox board — use the sysfs paths above.)

---

## ROLLBACK (if the new kernel misbehaves but board still boots)
```sh
# on the board
flashcp -v /mnt/sdcard/mtd3-boot.backup /dev/mtd3
rm -f /etc/init.d/S14zram
# restore S15sdmount swapfile line if you want SD swap back
reboot
```

## RECOVERY (if the board bricks / won't boot)
Serial console: **UART2, 1500000 8N1** (watch for u-boot / kernel logs).

Maskrom re-flash of just the boot partition:
```sh
# hold BOOT button while powering / resetting to enter maskrom, then on the Mac:
cd tools/linux/Linux_Upgrade_Tool
sudo ./upgrade_tool ul <idblock/uboot as needed>       # if needed
sudo ./upgrade_tool wl 0x100000 /path/to/mtd3-boot.backup   # write boot @ 4M offset
# 0x100000 = boot partition offset (256K env + 256K idblock + 512K uboot = 0x100000)
sudo ./upgrade_tool rd                                  # reset/reboot
```
Partition map (from BoardConfig): `256K(env),256K(idblock),512K(uboot),4M(boot),
30M(oem),10M(userdata),210M(rootfs)` — boot starts at offset **0x100000**.

Keep `mtd3-boot.backup` on the SD card until zram is confirmed working.

---

## Optional (NOT bundled here): noatime
Already handled on this board — `S21noatime` remounts `/userdata` noatime and the
rootfs gets `rootflags=noatime` from the kernel cmdline. Nothing to do.

## Tunables in S14zram
- `DISKSIZE=384M`  (~1.5x RAM; virtual cap, real RAM use bounded by compression)
- `COMP=zstd`      (fallback lzo)
- `SWAPPINESS=150` (kernel max is 200 on this tree; zram is fast so bias high)
