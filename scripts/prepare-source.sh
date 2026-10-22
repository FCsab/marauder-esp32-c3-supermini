#!/usr/bin/env bash
# Rebuild the vendored source tree (./source) from upstream Marauder at the
# pinned commit, with the C3 SuperMini patch applied.
#
# The repository already contains a complete source tree, so this is only
# needed when moving to a new upstream version or re-deriving the patch.
set -euo pipefail

SRC="${MARAUDER_SRC:-$HOME/esp32marauder}"
COMMIT="be4f42811538177f0f18e6ef6f5f681c297942e5"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
PATCH="$ROOT/patches/marauder-c3-supermini.patch"
DEST="$ROOT/source"

if [ ! -d "$SRC/.git" ]; then
  git clone https://github.com/justcallmekoko/ESP32Marauder.git "$SRC"
fi

cd "$SRC"
git fetch --quiet origin "$COMMIT" 2>/dev/null || true
git checkout --quiet "$COMMIT"
git reset --hard --quiet "$COMMIT"
git clean -fdq

git apply "$PATCH"

# Export the buildable tree only: artwork, CAD, old binaries and release
# images stay out of the repository.
rm -rf "$DEST"
mkdir -p "$DEST"
tar -C "$SRC" -cf - \
  --exclude='./.git' \
  --exclude='./.gitmodules' \
  --exclude='./.gitignore' \
  --exclude='./esp32_marauder/PreviousVersions' \
  --exclude='./pictures' \
  --exclude='./mechanical' \
  --exclude='./PCBs' \
  --exclude='./FlashFiles' \
  --exclude='./Release Bins' \
  --exclude='./C5_Py_Flasher_for_adapter' \
  --exclude='./C5_Py_Flasher_for_mini_v3' \
  --exclude='./C5_Py_Flasher_for_v8' \
  . | tar -C "$DEST" -xf -

echo "Vendored $COMMIT into $DEST."
