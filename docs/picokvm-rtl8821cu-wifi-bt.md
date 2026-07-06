# PicoKVM — RTL8821CU USB WiFi + Bluetooth (BT+AC600 dongle)

Adds support for the Realtek **RTL8821CU** USB combo dongle (labelled
"BT+AC600"), USB id `0bda:c820`. One chip, two radios:

- **WiFi** — AC600 (433 Mbps 5 GHz + 150 Mbps 2.4 GHz), out-of-tree
  `rtl8821cu` driver (morrownr 8821cu).
- **Bluetooth** — BT 4.2, in-kernel `btusb`/`btrtl` stack + Realtek firmware,
  driven by BlueZ from Entware (`/opt`).

## Why not the stock 88x2bu driver

The board previously shipped `88x2bu.ko` (RTL8812BU/8822BU family) in
`/lib/modules/5.10.160/extra`. It does **not** claim `0bda:c820`, so no
`wlan0` ever appeared. The RTL8821CU needs the `8821cu` driver.

## What was wired in

| Area | File |
|------|------|
| WiFi driver source | `sysdrv/drv_ko/wifi/rtl8821cu/` (morrownr 8821cu) |
| WiFi build hook | `sysdrv/drv_ko/wifi/Makefile` (`RTL8821CU` case) |
| Enable WiFi + chip | `BoardConfig-EMMC-...-KVM-IPC.mk` (`RK_ENABLE_WIFI=y`, `RK_ENABLE_WIFI_CHIP=RTL8821CU`) |
| BT kernel modules | `arch/arm/configs/rv1106-kvm.config` (`CONFIG_BT`, `BT_HCIBTUSB`, `BT_RTL`, `RFKILL`, crypto) |
| BT firmware | `overlay-picokvm/lib/firmware/rtl_bt/rtl8821c_{fw,config}.bin` |
| Boot: load drivers | `overlay-picokvm/etc/init.d/S30rtldrv` |
| Boot: BlueZ daemon | `overlay-picokvm/etc/init.d/S40bluetoothd` |
| Boot: WiFi assoc | `overlay-picokvm/etc/init.d/S45wifi` (stock; reads `/mnt/sdcard/wpa_supplicant.conf`) |

Boot order: `S20dbus` (Entware) → `S30rtldrv` → `S40bluetoothd` → `S45wifi`.

## Building the module out-of-tree (no full image rebuild)

The SDK toolchain is a Linux x86_64 binary, so builds run in a Linux
container (OrbStack amd64). The module must match the running kernel's ABI —
in particular use the board's exact config:

```sh
# in an amd64 Linux container with the repo mounted at /work
export PATH=/work/tools/linux/toolchain/arm-rockchip830-linux-uclibcgnueabihf/bin:$PATH
cd /work/sysdrv/source/kernel
ssh root@<board> 'zcat /proc/config.gz' > .config     # exact running-kernel config
make ARCH=arm CROSS_COMPILE=arm-rockchip830-linux-uclibcgnueabihf- olddefconfig modules_prepare
cd /work/sysdrv/drv_ko/wifi/rtl8821cu
make ARCH=arm CROSS_COMPILE=arm-rockchip830-linux-uclibcgnueabihf- KSRC=/work/sysdrv/source/kernel modules
```

### Gotcha: CONFIG_JUMP_LABEL / struct module ABI

`make olddefconfig` silently drops `CONFIG_JUMP_LABEL` (and flips the
STACKPROTECTOR choice). `CONFIG_JUMP_LABEL` changes the layout of
`struct module`, so a module built without it **panics the running kernel in
`load_module`** (walks off the modinfo string section). After `olddefconfig`,
force it back to match the board:

```sh
./scripts/config --file .config -e JUMP_LABEL -e STACKPROTECTOR_REGULAR -d STACKPROTECTOR_STRONG
make ARCH=arm CROSS_COMPILE=... olddefconfig modules_prepare
```

Verify the module vermagic matches the board's other modules:
`5.10.160 mod_unload ARMv7 thumb2 p2v8`.

## Bluetooth userspace (BlueZ via Entware)

`CONFIG_BT` is not in the base kernel, and BlueZ isn't cross-compiled against
uClibc. Entware (already installed at `/opt`, self-contained musl) provides it:

```sh
opkg update
opkg install bluez-utils bluez-utils-extra bluez-daemon
# power-on the controller automatically:
sed -i 's/^#*AutoEnable=.*/AutoEnable=true/' /opt/etc/bluetooth/main.conf
```

### Gotcha: RTL8821CU BT firmware download is flaky

The first `btusb` firmware download often times out (`download fw command
failed (-110)`); reloading `btusb` succeeds. `S30rtldrv` retries the
`btusb` load until dmesg shows `hci0: RTL: fw version`.

## Verify

```sh
lsmod | grep -E '8821cu|btusb|bluetooth'
wpa_cli -i wlan0 status | grep wpa_state          # COMPLETED
bluetoothctl show | grep Powered                  # yes
echo -e 'scan on\nsleep 12\ndevices\nquit' | bluetoothctl | grep '^Device'
```
