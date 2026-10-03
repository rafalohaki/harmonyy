#!/usr/bin/env bash
#
# Copy the platform-agnostic core into the ArkTS module.
#
# core/ is the single source of truth for the rewrite engine: it is tested with
# plain Node and type-checked with tsc, neither of which needs the SDK. The ArkTS
# module needs the same files on its own source path, so they are copied and
# transformed rather than duplicated by hand.
#
# The transform matters: Node's ESM resolver requires explicit file extensions
# ('./contracts.ts'), while the ArkTS toolchain resolves extensionless specifiers
# ('./contracts'). Rather than compromise either side, the copy strips the
# extension from relative import specifiers only.
#
# Never edit the copies; edit core/ and re-run this.
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

node -e '
  const fs = require("fs");
  const path = require("path");
  const root = process.argv[1];

  function walk(dir) {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) { walk(full); continue; }
      if (!entry.name.endsWith(".ts")) { continue; }
      const before = fs.readFileSync(full, "utf8");
      // Only relative specifiers inside a from clause, only when they end in .ts.
      const after = before.replace(
        /(from\s+[\x27"])(\.\.?\/[^\x27"]+?)\.ts([\x27"])/g,
        "$1$2$3"
      );
      if (after !== before) {
        fs.writeFileSync(full, after);
        console.log("  rewrote imports: " + path.relative(root, full));
      }
    }
  }

  walk(root);
' "$DEST"

# Prove the transform did what it claims instead of trusting it.
if grep -rn "from '\.\{1,2\}/[^']*\.ts'" "$DEST" >/dev/null 2>&1; then
  echo "ERROR: relative imports still carry a .ts extension:" >&2
  grep -rn "from '\.\{1,2\}/[^']*\.ts'" "$DEST" >&2
  exit 1
fi
echo "verified: no .ts extensions remain in relative imports"

echo "synced core -> $DEST"
find "$DEST" -name '*.ts' -print | sed "s|$BRIDGE_REPO_ROOT/||" | sort

cat <<'MSG'

Note: the copies under app/entry/src/main/ets/core/ are generated. Edit core/src
instead and re-run this script.
MSG
