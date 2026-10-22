#!/usr/bin/env bash
# Flash the prebuilt Marauder image onto an ESP32-C3 SuperMini.
#
# Writes the merged 4 MB image at 0x0, which covers bootloader, partition
# table, OTA data and application in one pass.
#
# Usage: ./flash-prebuilt.sh [port]        (default /dev/ttyACM0)

set -euo pipefail

PORT="${1:-/dev/ttyACM0}"
HERE="$(cd "$(dirname "$0")" && pwd)"
IMG="$HERE/../firmware/esp32_marauder_v1.19.2_c3_supermini_merged.bin"

if [ ! -f "$IMG" ]; then
  echo "error: $IMG not found" >&2
  exit 1
fi

if command -v esptool >/dev/null 2>&1; then
  ESPTOOL=(esptool)
elif command -v esptool.py >/dev/null 2>&1; then
  ESPTOOL=(esptool.py)
elif python3 -c "import esptool" >/dev/null 2>&1; then
  ESPTOOL=(python3 -m esptool)
else
  echo "error: esptool not found. Install it with: python3 -m pip install esptool" >&2
  exit 1
fi

"${ESPTOOL[@]}" --chip esp32c3 -p "$PORT" -b 921600 \
  write_flash --flash_mode dio --flash_freq 80m --flash_size 4MB \
  0x0 "$IMG"

echo "Done. Open $PORT at 115200 baud for the Marauder CLI."
