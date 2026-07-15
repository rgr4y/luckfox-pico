#!/usr/bin/env bash
# Build the ESP-Hosted-NG slave firmware for the ESP32-C5 (SDIO transport)
# reproducibly via Docker — no local ESP-IDF. Output: network_adapter/build/network_adapter.bin
#
# Usage: ./build.sh [target]     (default target: esp32c5)
set -euo pipefail
cd "$(dirname "$0")"

TARGET="${1:-esp32c5}"
IMG=esp-c5-slave

echo ">> building idf image ($IMG)..."
docker build -q -t "$IMG" . >/dev/null

echo ">> idf.py set-target $TARGET && build"
# IDF auto-merges sdkconfig.defaults + sdkconfig.defaults.$TARGET on set-target.
# C5 defaults to the SDIO transport (Kconfig: ESP_SDIO_HOST_INTERFACE if slave-capable).
docker run --rm -v "$PWD/network_adapter:/project" -w /project "$IMG" \
  bash -lc "idf.py set-target $TARGET && idf.py build"

BIN=network_adapter/build/network_adapter.bin
if [ -f "$BIN" ]; then
  echo ">> OK: $BIN"
  ls -la "$BIN"
else
  echo ">> FAILED: no $BIN" >&2
  exit 1
fi
