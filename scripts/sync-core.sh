#!/usr/bin/env bash
#
# Copy the platform-agnostic core into the ArkTS module.
#
# core/ is the single source of truth for the rewrite engine: it is tested with
# plain Node and type-checked with tsc, neither of which needs the SDK. The ArkTS
# module needs the same files on its own source path, so they are copied rather
# than duplicated by hand. Never edit the copies; edit core/ and re-run this.
#
# Usage:
#   scripts/sync-core.sh

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"

SRC="$BRIDGE_REPO_ROOT/core/src"
DEST="$BRIDGE_REPO_ROOT/app/entry/src/main/ets/core"

if [ ! -d "$SRC" ]; then
  echo "core/src not found at $SRC" >&2
  exit 1
fi

mkdir -p "$DEST"

# Mirror the tree, removing stale files so a deleted module cannot linger.
rm -rf "$DEST"
mkdir -p "$DEST"
cp -R "$SRC/." "$DEST/"

echo "synced core -> $DEST"
find "$DEST" -name '*.ts' -print | sed "s|$BRIDGE_REPO_ROOT/||" | sort

cat <<'MSG'

Note: the copies under app/entry/src/main/ets/core/ are generated. Edit core/src
instead and re-run this script.
MSG
