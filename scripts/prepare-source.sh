#!/usr/bin/env bash
# Clone ESP32 Marauder at the pinned upstream commit and apply the
# C3 SuperMini patch. Idempotent: re-running resets the tree first.
set -euo pipefail

SRC="${MARAUDER_SRC:-$HOME/esp32marauder}"
COMMIT="be4f42811538177f0f18e6ef6f5f681c297942e5"
HERE="$(cd "$(dirname "$0")" && pwd)"
PATCH="$HERE/../patches/marauder-c3-supermini.patch"

if [ ! -d "$SRC/.git" ]; then
  git clone https://github.com/justcallmekoko/ESP32Marauder.git "$SRC"
fi

cd "$SRC"
git fetch --quiet origin "$COMMIT" 2>/dev/null || true
git checkout --quiet "$COMMIT"
git reset --hard --quiet "$COMMIT"
git clean -fdq

git apply "$PATCH"
echo "Prepared $SRC at $COMMIT with the C3 SuperMini patch applied."
