#!/usr/bin/env bash
# Open an interactive serial monitor on the Marauder CLI.
#
# Usage: ./monitor.sh [port]        (default /dev/ttyACM0)

set -euo pipefail

PORT="${1:-/dev/ttyACM0}"

if command -v arduino-cli >/dev/null 2>&1; then
  exec arduino-cli monitor -p "$PORT" -c baudrate=115200
fi

exec python3 -m serial.tools.miniterm "$PORT" 115200 --dtr 0 --rts 0
