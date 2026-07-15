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
| CD   | GPIO2_A6     | 70    | I2C3_M0_SCL pad |

GND at header pin 23 (adjacent). 3V3 from pin 36 (3V3 OUT).

**CD (card-detect)** is not standard SDIO — it's how we keep an empty slot silent
(see Step 1). Wire the ESP32's ready/present line (any spare ESP GPIO, driven LOW
when the ESP is up) to GPIO2_A6. Active-low = card present; an internal pull-up
holds it HIGH (no card) when the ESP is off/absent, so a board with no ESP boots
clean. Confirm the GPIO2_A6 pad against the board silkscreen before soldering.

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
	/* card-detect (NOT non-removable) so an empty slot is silent at boot:
	 * mmc_rescan sees get_cd()==0 -> powers the host off -> no probe, no
	 * "error -110 whilst initialising SDIO card". */
	cd-gpios = <&gpio2 RK_PA6 GPIO_ACTIVE_LOW>;
	no-1-8-v;                 /* ESP32 SDIO slave is 3.3V */
	max-frequency = <50000000>;
	pinctrl-names = "default";
	pinctrl-0 = <&sdmmc1m0_clk &sdmmc1m0_cmd &sdmmc1m0_bus4 &sdio_cd_pin>;
	status = "okay";
};

&pinctrl {
	sdio {
		sdio_cd_pin: sdio-cd-pin {
			rockchip,pins = <2 RK_PA6 RK_FUNC_GPIO &pcfg_pull_up>;
		};
	};
};
```

Pinctrl group labels (already defined in `rv1106-pinctrl.dtsi`, `sdmmc1` block):
`sdmmc1m0_clk`, `sdmmc1m0_cmd`, `sdmmc1m0_bus4` (d0–d3). `sdio_cd_pin` is our
own group (GPIO2_A6 as GPIO with pull-up) for the ESP ready/present line.

**Why card-detect over `non-removable`:** with `non-removable` the MMC core
scans the slot once at boot even when empty and logs an SDIO init error; there
is no on-chip route to suppress it. A `cd-gpios` line lets `mmc_rescan` take the
`get_cd()==0` early-out (`drivers/mmc/core/core.c`), powering the host off
silently. Costs one wire from the ESP; makes the no-ESP case boot clean.

Optional: a `mmc-pwrseq-simple` node wired to an ESP reset GPIO for clean
power-on ordering. Not required for first bring-up.

## Step 2 — Kernel module (ESP-Hosted-NG)

`esp32_sdio` is an **out-of-tree** module — build against this 5.10 tree using the
**Status: integrated + build-verified.** The NG host driver
(`espressif/esp-hosted`, `esp_hosted_ng/host/`) is vendored at
`sysdrv/drv_ko/esp_hosted/` (source + wrapper Makefile) and wired into
`sysdrv/drv_ko/Makefile` `M_DIRS`, so a normal `./build.sh` compiles
`esp32_sdio.ko` into the rootfs `/ko`. It is deliberately **absent from
`sysdrv/drv_ko/insmod_ko.sh`** → shipped but NOT auto-loaded (install image →
wire ESP → `modprobe`).

Three fixes were required to build the upstream driver against this SDK's strict
5.10 kernel (all live in the vendored copy):
- `host/Makefile`: `ccflags-y += -Wno-error=declaration-after-statement`
  (kernel forces `-Werror`; driver isn't C90-clean).
- `host/Makefile`: `CC=$(CROSS_COMPILE)gcc` on the modules line — bypasses
  Rockchip's `scripts/gcc-wrapper.py` forbidden-warning gate for this module.
- `host/main.c`: `MODULE_IMPORT_NS(VFS_internal_I_am_really_a_filesystem_and_am_NOT_a_driver)`
  — driver uses `filp_open`/`kernel_read` (guarded VFS symbol namespace in 5.10).

Kernel deps (defconfig): `CONFIG_CFG80211=m` (already present) + **`CONFIG_BT=m`**
(added — the driver bundles BT-over-HCI; also lights up the rtl8821cu BT half,
whose `rtl_bt` firmware was already shipped but had no stack). Both are modules.

Built on Google Cloud Shell via the `Dockerfile.build` image (native x86, no
case-collision hack). Runtime, after wiring the ESP:
```sh
modprobe esp32_sdio      # pulls cfg80211 + bluetooth (if depmod ran)
dmesg | grep -iE "esp32|wlan"
ip link show wlan0
```

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

## Step 4 — ESP slave = **DFRobot FireBeetle 2 ESP32-C5** (chosen)

Only ESP32 (classic), C5, C6 have the SDIO-**slave** peripheral. S3/C3 are host-
or SPI-slave-only (their SDMMC block is host-side; no `sdio_slave` IDF driver).
Picked the **C5** (have one): dual-band WiFi 6 (2.4+5GHz), and it's the throughput
king — ESP-Hosted-NG bench: **C5 SDIO 5GHz ≈ 63/52 TCP, 97/81 UDP Mbps** vs ESP32
22.9/15.6 and C6 22.4/25.6. NG supports C5 as a slave (variant table: ESP32,
C2/C3/C5/C6/C61, S2/S3), cfg80211 → real `wlan0`.

**C5 SDIO-slave GPIOs (fixed IO_MUX, verified vs esp-hosted-mcu `docs/sdio.md`):**

| Signal | C5 GPIO | FireBeetle access            | RV1106 pin / GPIO | 51k PU→3V3 |
|--------|---------|------------------------------|-------------------|------------|
| CLK    | IO9     | header `9/SDA`               | 26 / GPIO2_A2     | —          |
| CMD    | IO10    | header `10/SCL`              | 27 / GPIO2_A3     | **✓**      |
| D0     | IO8     | header `8/D2`                | 25 / GPIO2_A1     | **✓**      |
| D1     | IO7     | header `7/D11`               | 24 / GPIO2_A0     | **✓** †    |
| D2     | IO14    | **USB D+ — R3 pad, lift R3** | 22 / GPIO2_A5     | **✓**      |
| D3     | IO13    | **USB D- — R2 pad, lift R2** | 21 / GPIO2_A4     | **✓**      |
| CD/rdy | spare   | any spare GPIO, drive LOW=up | GPIO2_A6 pad      | (RV int PU)|
| GND    | GND     | GND                          | 23                | —          |
| 3V3    | 3V3     | 3V3 (or self-power via USB-C)| 36                | —          |

- RV1106 pins 21–27 = one block (23=GND mid). C5 side: 4 on headers + 2 tapped.
- **DAT2/DAT3 = IO14/IO13 = the C5's native USB D±** (schematic: R3=D+/USB_P,
  R2=D-/USB_N, 22R series). They're NOT on the FireBeetle headers — only at the
  USB-C data pins. Tap the module side of R2/R3 and **lift R2/R3** to isolate the
  connector (USB-C then = power + ROM-download only, no runtime USB data — fine
  for a headless WiFi co-proc). ROM/boot log still comes out **UART0** (default
  on, datasheet Table 4-5); flash via USB-JTAG download mode (BOOT+RST) *before*
  lifting R2/R3, or via UART0 after.
- Pull-ups **mandatory** (Espressif: 51k rec; 10k fine). D2/D3 pull-ups also stop
  the slave falling into SPI boot mode.
- **† IO7 (DAT1) is also the JTAG-source strap** (datasheet §4.4): no internal
  pull, must not be high-Z at boot. The mandatory DAT1 pull-up satisfies that —
  one resistor, two jobs.
- **Clock-edge tuning:** GPIO25 + MTDI set SDIO sample/drive edges (Table 4-4,
  floating default). If the link is flaky at `max-frequency`, flip these before
  suspecting wiring.
- **CD/ready:** C5 firmware drives a spare GPIO LOW when its SDIO slave is up →
  clean enumerate; or tie GPIO2_A6 to C5 GND (present when board attached, may
  cost one `mmc_rescan`). No C5 → RV pull-up → slot silent.

**Flash order (avoid a chicken-and-egg):** flash the C5 NG slave firmware over
USB-C *first* (IO13/14 still = USB), then lift R2/R3 + solder the 6 SDIO leads.
Reflashes after that go over UART0 download mode.

**⚠ host-driver ↔ slave-fw generation — verify before building fw:** the host
`.ko` we vendored is **ESP-Hosted-NG** (`esp32_sdio.ko`, `target=sdio`). Confirm
the vendored NG snapshot actually includes **C5** slave support (C5 is recent) —
if the NG tree is too old, re-vendor latest NG or move host+slave to the unified
`esp-hosted` stack together (never mix generations across the link).

---

## Hardware gotchas (VERIFY before soldering)

- **Pull-ups on CMD + D0–D3** (~10–51k to 3V3). SDIO needs them; ESP-Hosted
  reference designs include them — don't omit.
- **Wire length.** SDIO @ 50 MHz is intolerant of long leads. Short soldered
  jumpers, not long DuPont. If flaky: drop `max-frequency`, or fall back to
  `bus-width = <1>`.
- **C5 strapping pins on the bus.** IO7 (DAT1) = JTAG-source strap (must not be
  high-Z — the DAT1 pull-up covers it); IO28 (BOOT) = SPI-boot strap; GPIO25/MTDI
  = SDIO clock-edge select. See Step 4. (N/A note: on a *classic* ESP32 the trap
  is instead IO12/MTDI = flash-voltage strap → needs `espefuse set_flash_voltage`.)
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
