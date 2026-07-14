# ESP-Hosted over SDIO — add non-USB WiFi to the Luckfox Pico Pro Max

Goal: bolt an ESP32 onto the RV1106 as a **native `wlan0`** WiFi NIC over the
SoC's dedicated (currently unused) SDIO controller — no USB dongle, no stealing
the SD-card slot. ESP-Hosted-NG (Espressif's "Next Gen", the Linux-host path)
presents a real cfg80211 802.11 netdev, driven by `wpa_supplicant` /
NetworkManager over an SDIO transport.

Status: **planned, verified, nothing flashed.** DT stanza + pin mapping proven
against source *and* the live board. Kernel module + ESP firmware are the
remaining build/flash work.

---

## Why this works — verified, not assumed

The RV1106 has **three separate MMC controllers** (`rv1106.dtsi`):

| Node   | Address    | Role on Pro Max                | pinctrl group |
|--------|------------|--------------------------------|---------------|
| `emmc` | `ffa90000` | unused                         | —             |
| `sdmmc`| `ffaa0000` | **SD card** (mmcblk1, 58.9 GB) | `sdmmc0_*` → microSD slot |
| `sdio` | `ff9a0000` | **`status="disabled"` — FREE** | `sdmmc1_*`    |

So the SD card and the SDIO peripheral are **different controllers on different
pins**. Enabling SDIO does not touch the SD slot. (The pasted vendor claim about
a dedicated SDIO block separate from SDMMC0 checked out this time.)

The `sdio` controller (`sdmmc1` in pinctrl terms) has two pin muxes:

- **m0 = GPIO2_A0–A5** ← use this. Clean group; alt funcs are only UART1/I2C4.
- m1 = GPIO1_C0–C5 — overlaps SPI0 + UART4. Messier. Skip.

### m0 pin map (SDIO 4-bit) → Pro Max header

| SDIO | DTS pin      | sysfs | Header pin |
|------|--------------|-------|------------|
| CLK  | GPIO2_A2     | 66    | **26**     |
| CMD  | GPIO2_A3     | 67    | **27**     |
| D0   | GPIO2_A1     | 65    | **25**     |
| D1   | GPIO2_A0     | 64    | **24**     |
| D2   | GPIO2_A5     | 69    | **22**     |
| D3   | GPIO2_A4     | 68    | **21**     |

GND at header pin 23 (adjacent). 3V3 from pin 36 (3V3 OUT).

### Live-board proof the pins are free

`/sys/kernel/debug/pinctrl/pinctrl-rockchip-pinctrl/pinmux-pins` on 10.0.1.13:

```
pin 64 (gpio2-0): (MUX UNCLAIMED) (GPIO UNCLAIMED)
pin 65 (gpio2-1): (MUX UNCLAIMED) (GPIO UNCLAIMED)
pin 66 (gpio2-2): (MUX UNCLAIMED) (GPIO UNCLAIMED)
pin 67 (gpio2-3): (MUX UNCLAIMED) (GPIO UNCLAIMED)
pin 68 (gpio2-4): (MUX UNCLAIMED) (GPIO UNCLAIMED)
pin 69 (gpio2-5): (MUX UNCLAIMED) (GPIO UNCLAIMED)
```

Pro Max dts enables only `sfc` (NAND), `sdmmc` (SD), `gmac` (eth), `usb`; `spi0`
disabled. Nothing claims GPIO2_A0–A5. Ethernet is on its own RMII pins.

---

## Step 1 — Device tree

Add to `sysdrv/source/kernel/arch/arm/boot/dts/rv1106g-luckfox-pico-pro-max.dts`
(the DT ships inside `resource.img` → `boot.img` → **mtd3**, same partition the
zram kernel went to, so this rides a boot.img rebuild):

```dts
/**********SDIO (ESP-Hosted WiFi)**********/
&sdio {
	bus-width = <4>;
	cap-sd-highspeed;
	cap-sdio-irq;
	keep-power-in-suspend;
	non-removable;
	no-1-8-v;                 /* ESP32 SDIO slave is 3.3V */
	max-frequency = <50000000>;
	pinctrl-names = "default";
	pinctrl-0 = <&sdmmc1m0_clk &sdmmc1m0_cmd &sdmmc1m0_bus4>;
	status = "okay";
};
```

Pinctrl group labels (already defined in `rv1106-pinctrl.dtsi`, `sdmmc1` block):
`sdmmc1m0_clk`, `sdmmc1m0_cmd`, `sdmmc1m0_bus4` (d0–d3).

Optional: a `mmc-pwrseq-simple` node wired to an ESP reset GPIO for clean
power-on ordering. Not required for first bring-up.

## Step 2 — Kernel module (ESP-Hosted-NG)

`esp32_sdio` is an **out-of-tree** module — build against this 5.10 tree using the
**same container pipeline as the zram build** (git-archive kernel into the
case-sensitive fs in the `lfbuild` amd64 container, `arm-rockchip830-...` toolchain).

- Repo: `espressif/esp-hosted`, `esp_hosted_ng/host/` Linux driver.
- Build as a module (`.ko`) against the RV1106 `KDIR`; stage under an overlay so
  it survives image rebuilds.
- Loads: `modprobe esp32_sdio` → registers `wlan0` via cfg80211.

## Step 3 — boot.img rebuild + flash (fold into zram pipeline)

The DT change requires a fresh `boot.img` (kernel + resource.img). Rebuild once,
flash mtd3 once — same procedure as `boot-zram.img`:

```sh
scp boot-sdio.img root@10.0.1.13:/mnt/sdcard/boot-sdio.img
# on board, BACK UP FIRST:
dd if=/dev/mtd3 of=/mnt/sdcard/mtd3-boot.backup bs=128k
flashcp -v /mnt/sdcard/boot-sdio.img /dev/mtd3
```

Rollback: `flashcp -v /mnt/sdcard/mtd3-boot.backup /dev/mtd3` (or the earlier
zram backup). Worst case: BOOT-button maskrom + `upgrade_tool`.

## Step 4 — ESP32 slave

- Flash **ESP-Hosted-NG slave firmware** for your ESP32 variant (SDIO transport).
- ESP32 SDIO-slave pins are **fixed in silicon** (classic ESP32):
  CLK=IO14, CMD=IO15, D0=IO2, D1=IO4, D2=IO12, D3=IO13. Verify for your exact
  chip (S3/C-series differ).
- Wire ESP pins ↔ RV1106 header pins per the map above (CLK↔CLK, etc.).

---

## Hardware gotchas (VERIFY before soldering)

- **Pull-ups on CMD + D0–D3** (~10–51k to 3V3). SDIO needs them; ESP-Hosted
  reference designs include them — don't omit.
- **Wire length.** SDIO @ 50 MHz is intolerant of long leads. Short soldered
  jumpers, not long DuPont. If flaky: drop `max-frequency`, or fall back to
  `bus-width = <1>`.
- **ESP32 strapping pins.** IO2/IO12 are boot-strapping pins — respect
  ESP-Hosted's documented pull requirements or the ESP won't boot.
- **3.3V only** (`no-1-8-v` set). Do not enable 1.8V signaling.

## Post-bringup verification

```sh
modprobe esp32_sdio
dmesg | grep -iE "esp32|sdio|wlan"          # slave probe + fw handshake
ls /sys/class/mmc_host/                     # expect a new mmc host @ ff9a0000
ip link show wlan0                           # netdev exists
iw dev wlan0 scan | grep SSID                # radio works
```

---

## Decision recap

- **NG, not FG.** NG = native `wlan0` for a Linux host (recommended by Espressif).
  FG = protobuf-RPC Ethernet iface, MCU-oriented (MCU support now split to the
  separate `esp-hosted-mcu` repo). NG limitation: no SoftAP.
- **SDIO, not SPI/UART.** SPI-NG works but caps at low-single-digit Mbps; UART
  can't carry WiFi data in ESP-Hosted at all (BT/HCI only). SDIO 4-bit @ 50 MHz
  = tens of Mbps, a real NIC.
- **Not USB.** Board already has RTL8821CU USB WiFi (driver disabled). This is the
  "do it because it's fun / free the USB port" path, not a necessity.

See also: `docs/zram-plan.md` (shared boot.img/mtd3 rebuild + flash pipeline),
`docs/picokvm-rtl8821cu-wifi-bt.md` (the USB WiFi this sidesteps).
