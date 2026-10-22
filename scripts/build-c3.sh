#!/usr/bin/env bash
# Build and flash ESP32 Marauder for a bare ESP32-C3 SuperMini (4 MB flash).
#
# Prerequisites:
#   arduino-cli >= 1.5
#   esp32:esp32 core 3.3.4
#   Libraries (exact versions matter):
#     NimBLE-Arduino 2.3.8, ArduinoJson 6.18.2, LinkedList 1.3.3,
#     ESP Async WebServer 3.8.1, Async TCP 3.4.8, ESP32Ping 1.6,
#     MicroNMEA 2.0.6, TFT_eSPI 2.5.34, XPT2046_Touchscreen 1.4,
#     JPEGDecoder 1.8.0, Adafruit NeoPixel 1.12.0, Adafruit BusIO,
#     Adafruit MAX1704X, EspSoftwareSerial 8.1.0, Adafruit_TCA8418
#
# Usage: ./build-c3.sh [port]        (default /dev/ttyACM0)

set -euo pipefail

SRC="${MARAUDER_SRC:-$HOME/esp32marauder}"
OUT="${MARAUDER_OUT:-$HOME/esp32marauder-build}"
PORT="${1:-/dev/ttyACM0}"
FQBN="esp32:esp32:esp32c3:FlashSize=4M,PartitionScheme=min_spiffs,CDCOnBoot=cdc"

if ! grep -q "MARAUDER_C3_SUPERMINI" "$SRC/esp32_marauder/configs.h"; then
  echo "error: C3 SuperMini profile not found in $SRC." >&2
  echo "       Run scripts/prepare-source.sh first." >&2
  exit 1
fi

mkdir -p "$OUT"

arduino-cli compile \
  --fqbn "$FQBN" \
  --build-property "compiler.cpp.extra_flags=-DMARAUDER_C3_SUPERMINI" \
  --build-property "compiler.c.elf.extra_flags=-Wl,-zmuldefs" \
  --warnings none \
  --output-dir "$OUT" \
  "$SRC/esp32_marauder"

arduino-cli upload \
  -p "$PORT" \
  --fqbn "$FQBN" \
  --input-dir "$OUT" \
  "$SRC/esp32_marauder"

echo "Flashed. Open $PORT at 115200 baud for the Marauder CLI."
