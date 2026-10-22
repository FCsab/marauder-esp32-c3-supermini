# ESP32 Marauder on the ESP32-C3 SuperMini

Unofficial port of [ESP32 Marauder](https://github.com/justcallmekoko/ESP32Marauder)
to the bare **ESP32-C3 SuperMini** (4 MB flash, no PSRAM, no display, no SD, no buttons).

Upstream ships no ESP32-C3 target. This repository contains the minimal source patch that
adds one, the build scripts used to produce and flash the firmware, and prebuilt images of
**Marauder v1.19.2** (upstream commit `be4f428`).

> **Not affiliated with justcallmekoko or the ESP32 Marauder project.**
> Test only on networks and devices you own or have explicit permission to assess.

---

## Status

Tested on real hardware. What was confirmed:

- Boots with the standard Marauder banner and drops to the `>` CLI over USB serial.
- `settings` loads, creates, and persists its SPIFFS config on first boot.
- `scanall` captured 21 APs plus station/AP pairs across channels 1, 6, 7, 11, 12.
- `sniffbt -t ibeacon` initializes the NimBLE stack and starts sniffer mode.
- `blespam -t windows` puts Swift Pair advertisements on air with the correct
  Microsoft vendor payload and a fresh address per burst. Verified from a second
  host (see BLE spam notes below).
- Builds and links cleanly at 79% of the app partition.

Not confirmed:

- The onboard WS2812 is mapped to **GPIO8**, but the LED was not visually verified.
  Test with `led -s 00ff00`.
- Transmit/attack paths were not exercised.
- Any feature requiring a screen, SD card, GPS module, or buttons is unavailable by design.

---

## Hardware

- ESP32-C3 SuperMini board with **4 MB** flash (the common variant).
- USB-C **data** cable. Many bundled cables are charge-only and will not enumerate.
- Nothing else. No display, SD, or button wiring is needed.

The board appears as `303a:1001 Espressif USB JTAG/serial debug unit` and as
`/dev/ttyACM0` on Linux.

---

## Install

### Option 1 — flash the prebuilt image

```bash
git clone https://github.com/FCsab/marauder-esp32-c3-supermini.git
cd marauder-esp32-c3-supermini
python3 -m pip install --user esptool
./scripts/flash-prebuilt.sh /dev/ttyACM0
```

Or invoke esptool directly:

```bash
esptool.py --chip esp32c3 -p /dev/ttyACM0 -b 921600 \
  write_flash --flash_mode dio --flash_freq 80m --flash_size 4MB \
  0x0 firmware/esp32_marauder_v1.19.2_c3_supermini_merged.bin
```

Images in `firmware/`:

- `esp32_marauder_v1.19.2_c3_supermini_merged.bin` — full 4 MB image, flash at `0x0`.
- `esp32_marauder_v1.19.2_c3_supermini.bin` — application only, flash at `0x10000`.
- `SHA256SUMS` — checksums for both.

### Option 2 — build from source

Toolchain:

```bash
mkdir -p ~/.local/bin
curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh \
  -o /tmp/arduino-cli-install.sh
sh /tmp/arduino-cli-install.sh -b ~/.local/bin
export PATH="$HOME/.local/bin:$PATH"

arduino-cli config init --overwrite
arduino-cli config add board_manager.additional_urls \
  https://espressif.github.io/arduino-esp32/package_esp32_index.json
arduino-cli core update-index
arduino-cli core install esp32:esp32@3.3.4
```

Libraries (versions matter — these mirror upstream CI):

```bash
for p in "NimBLE-Arduino@2.3.8" "ArduinoJson@6.18.2" "LinkedList@1.3.3" \
         "ESP Async WebServer@3.8.1" "Async TCP@3.4.8" \
         "MicroNMEA@2.0.6" "TFT_eSPI@2.5.34" \
         "XPT2046_Touchscreen@1.4" "JPEGDecoder@1.8.0" \
         "Adafruit NeoPixel@1.12.0" "Adafruit BusIO@1.15.0" \
         "Adafruit MAX1704X@1.0.2" "EspSoftwareSerial@8.1.0"; do
  arduino-cli lib install "$p"
done

git clone --depth 1 --branch 1.6 \
  https://github.com/marian-craciunescu/ESP32Ping.git \
  "$HOME/Arduino/libraries/ESP32Ping"
```

`Adafruit_TCA8418` is not in the Arduino registry; it ships with upstream Marauder:

```bash
cp -r source/libraries/Adafruit_TCA8418 "$HOME/Arduino/libraries/"
```

Build it:

```bash
./scripts/build-c3.sh /dev/ttyACM0
```

The complete patched source tree is in `source/`, so no checkout or patch step is
needed. `scripts/prepare-source.sh` is only for regenerating that tree from
upstream: it clones `be4f428` into `~/esp32marauder` (override with `MARAUDER_SRC`),
applies `patches/marauder-c3-supermini.patch`, and re-exports `source/`.

---

## Usage

Open the CLI:

```bash
./scripts/monitor.sh /dev/ttyACM0
```

Equivalent manual commands:

```bash
arduino-cli monitor -p /dev/ttyACM0 -c baudrate=115200
# or
python3 -m serial.tools.miniterm /dev/ttyACM0 115200 --dtr 0 --rts 0
```

Notes:

- Opening the port resets the C3, so the ROM lines and banner appear first. Output
  emitted before the monitor attached is lost — that is normal USB-CDC behaviour.
- Commands are line-based, terminated by Enter.
- Exit with `Ctrl-C` (arduino-cli) or `Ctrl-]` (miniterm).

Example session:

```
> help
> settings
> scanall
> stopscan
> list -a
> led -s 00ff00
> reboot
```

### BLE spam notes

`blespam -t windows` sends the Microsoft Swift Pair payload from the Swift Pair
specification:

```
FF 06 00        manufacturer specific data, vendor Microsoft (0x0006)
03              Swift Pair beacon ID
00              sub-scenario 0x00 = pairing over BLE only
80              reserved RSSI byte
<name>          optional display name, random per burst
```

Measured on air from a second host (`bleak` scanner, company ID `0x0006`):
~4 advertisements per second per burst and a different BLE address for each burst.

`blespam -t all` cycles all six payload types. Because every type now holds the air
for 150 ms plus a NimBLE init/deinit cycle, a full round takes roughly 1.5–2 s.

---

## How the port works

The patch is deliberately small — four edits across three files:

- `esp32_marauder/configs.h`
  - Adds the `MARAUDER_C3_SUPERMINI` hardware name.
  - Adds a capability block: `HAS_BT`, `HAS_NEOPIXEL_LED`, `HAS_NIMBLE_2`, `HAS_IDF_3`,
    and nothing else — no screen, SD, buttons, GPS, PSRAM, or dual band.
  - Maps the WS2812 data pin to GPIO8.
- `esp32_marauder/AXP192.cpp`
  - Guards the whole translation unit with `#ifdef HAS_AXP192`. The file unconditionally
    used `Wire1`, which does not exist on the C3, so it failed to compile even though no
    C3 board has that PMIC.
- `esp32_marauder/WiFiScan.cpp` — BLE spam fixes (Microsoft Swift Pair, Google,
  Samsung, Flipper Zero):
  - The advertising burst was 10 ms once per second while NimBLE's default interval is
    30–60 ms, so most bursts emitted **zero** packets. It now uses the 20 ms minimum
    interval and stays on air for 150 ms.
  - Each burst advertises from a fresh static-random BLE address.
    `esp_base_mac_addr_set()` is ignored once the radio has been initialised, so the
    address is set through `NimBLEDevice::setOwnAddr()` plus
    `setOwnAddrType(BLE_OWN_ADDR_RANDOM)`. Windows shows one Swift Pair toast per
    address, so rotation is what makes repeated popups possible.

Build configuration:

```
FQBN: esp32:esp32:esp32c3:FlashSize=4M,PartitionScheme=min_spiffs,CDCOnBoot=cdc
-DMARAUDER_C3_SUPERMINI
-Wl,-zmuldefs
```

`-Wl,-zmuldefs` is the same workaround upstream CI applies: Marauder defines
`connectionPending` / `operationInProgress` in a header and supplies its own
`ieee80211_raw_frame_sanity_check`, which collide with the ESP-IDF net80211 library
on this target.

Resource usage of the shipped build:

- Application: 1,566,862 bytes — 79% of the 1,966,080-byte `min_spiffs` app partition.
- Static RAM: 58,976 bytes (17%) — roughly 268 KB left for the heap.

---

## Limitations

- **Headless.** No TFT, SD card, GPS, or buttons. Display menus, PCAP-to-SD logging, and
  Wigle uploads are unavailable. Everything runs through the serial CLI.
- **Radio.** ESP32-C3 is 2.4 GHz WiFi plus BLE 5.0 only — no 5 GHz and no Bluetooth Classic.
- **Flash.** 4 MB total. The `min_spiffs` layout leaves ~1.9 MB per app slot; OTA/web upload
  (`HAS_DIRECT_UPLOAD`) is disabled in this build.
- **Shared radio.** WiFi and BLE cannot run simultaneously; switching modes reinitializes
  the stack and can take a second or two.
- Upstream changes may break the patch. It is pinned to `be4f428` (v1.19.2).

---

## Recovery

The C3's USB-Serial/JTAG ROM loader is always reachable:

1. Hold **BOOT**.
2. Plug in USB (or tap **RST** while holding BOOT).
3. Release BOOT and flash again.

If a bad image leaves the board in a boot loop, this recovers it without any special tool.

---

## Repository layout

- `source/` — complete ESP32 Marauder source tree at upstream `be4f428` with the
  C3 SuperMini patch applied (sketch, `libraries/`, display setup headers, tools,
  unit tests, upstream README and LICENSE). This is the tree `build-c3.sh` compiles.
- `patches/marauder-c3-supermini.patch` — the same changes as a diff against
  upstream, for review or upstreaming.
- `scripts/prepare-source.sh` — regenerate `source/` from upstream at the pinned
  commit and re-apply the patch.
- `scripts/build-c3.sh` — compile `source/` and flash via arduino-cli.
- `scripts/flash-prebuilt.sh` — flash the merged image via esptool.
- `scripts/monitor.sh` — open the serial CLI.
- `firmware/` — prebuilt images and `SHA256SUMS`.

Not vendored, to keep the repository small: upstream `pictures/`, `mechanical/`,
`PCBs/`, `FlashFiles/`, `Release Bins/`, the C5 Python flasher bundles, and
`esp32_marauder/PreviousVersions/` (106 MB of old binaries). All of them are
available in the upstream repository. Arduino library dependencies are not
vendored either; the build section above pins their versions.

---

## License and credits

ESP32 Marauder is MIT licensed, Copyright (c) 2020 Just Call Me Koko.
This port keeps the same license; see `LICENSE`.

- Upstream: https://github.com/justcallmekoko/ESP32Marauder
- Pin: `be4f42811538177f0f18e6ef6f5f681c297942e5` (v1.19.2)

Build tooling, patch, and documentation in this repository are provided as-is, without
warranty. You are responsible for how you use the firmware.
