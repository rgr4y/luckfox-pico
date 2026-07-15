# ESP-Hosted-NG slave firmware — ESP32-C5 (Luckfox RV1106 trio)

WiFi/BT co-processor firmware for the **DFRobot FireBeetle 2 ESP32-C5**, paired
with the RV1106 (Luckfox Pico Pro Max) running the ESP-Hosted-NG **host** driver
(`esp32_sdio.ko`, vendored in `sysdrv/drv_ko/esp_hosted/`). NG presents a real
cfg80211 `wlan0` on the Linux host over an **SDIO** transport.

- Source: `network_adapter/` = Espressif `esp_hosted_ng/esp/esp_driver/network_adapter`, **NG 1.0.5.0.3** (see `network_adapter/NG_VERSION`).
- Transport: **SDIO** — the C5 Kconfig default (`ESP_SDIO_HOST_INTERFACE if SOC_SDIO_SLAVE_SUPPORTED`). No menuconfig change needed.
- Host/slave generations MUST match: both NG. Don't pair this with the `esp_hosted`/MCU component.

## Build — just `make` (Docker idf, no local IDF)

```sh
make                    # -> network_adapter/build/network_adapter.bin
make flash PORT=/dev/tty.usbmodem*    # host esptool; download mode = BOOT+RST
make monitor PORT=...                 # serial @115200
make menuconfig | clean | shell | bin | help
```
Build runs in `espressif/idf:v5.5.1` (Docker). flash/monitor run on the host —
`pip install esptool pyserial`. (`./build.sh` is the same build without make.)

## Build (local ESP-IDF >= v5.5)

```sh
cd network_adapter
idf.py set-target esp32c5      # auto-merges sdkconfig.defaults.esp32c5
idf.py build                    # -> build/network_adapter.bin
```

## Build (PlatformIO) — best-effort

C5 needs the **pioarduino fork** (official `espressif32` errors on C5). See
`platformio.ini`. This is an IDF-native `main/` project; pio-espidf expects
`src/`, so `pio run` may need massaging. If it fights, use `./build.sh`.

## Flash

**Order matters** (IO13/IO14 = USB D-/D+ get repurposed as SDIO DAT3/DAT2):
flash over USB-C **first**, then lift R2/R3 + solder the SDIO leads.

```sh
# USB-C in download mode (BOOT+RST), IDF esptool inside the docker image or local:
idf.py -p /dev/ttyACM0 flash        # or: esptool.py --chip esp32c5 write_flash ...
```
After R2/R3 are lifted, reflash over **UART0** download mode instead.

## Wiring → RV1106

See `docs/esp-hosted-sdio-plan.md` in the luckfox-pico tree (Step 4). C5 SDIO
slave fixed pins: CLK=IO9, CMD=IO10, DAT0=IO8, DAT1=IO7, DAT2=IO14, DAT3=IO13
(DAT2/3 tapped from USB D±). 47k–51k pull-ups on CMD+DAT0–3.

## Known C5 caveat

The old `feat/esp32c5_ng_beta_support` branch had a `wlan0` MAC = `00:00:00:00:00:00`
bug. This is NG master (post-merge). If `wlan0` shows an all-zero MAC and can't
associate, that regression is the first suspect — check `ip link show wlan0`.
