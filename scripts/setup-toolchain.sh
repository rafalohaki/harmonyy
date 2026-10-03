#!/usr/bin/env bash
#
# Install the DevEco command line interface locally and report what is missing.
#
# This step is deliberately separated from the SDK and emulator work: the CLI is
# a thin wrapper, and knowing whether the wrapper or the toolchain is missing
# saves a lot of guessing.
#
# Usage:
#   scripts/setup-toolchain.sh

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"

DEVECO_CLI_VERSION="1.3.4"

echo "== Node.js =="
if ! command -v node >/dev/null 2>&1; then
  echo "node is not on PATH. Install Node.js 22 or later." >&2
  exit 1
fi

node_major="$(node -p 'process.versions.node.split(".")[0]')"
echo "node $(node --version)"
if [ "$node_major" -lt 22 ]; then
  echo "devecocli requires Node.js 22 or later (found $node_major)." >&2
  exit 1
fi

# The default npm cache can contain root-owned files from earlier installs,
# which makes a global install fail with EPERM. A private cache avoids that
# without asking for sudo.
CACHE_DIR="${BRIDGE_NPM_CACHE:-$BRIDGE_REPO_ROOT/.home/npm-cache}"
mkdir -p "$CACHE_DIR"

echo
echo "== Installing @deveco/deveco-cli@$DEVECO_CLI_VERSION =="
if [ -x "$BRIDGE_CLI" ]; then
  echo "already present: $($BRIDGE_CLI -V 2>/dev/null || echo unknown)"
else
  # Installed into the repository, not globally: reproducible, and it keeps the
  # machine's global npm prefix untouched.
  ( cd "$BRIDGE_REPO_ROOT" && npm install --prefix .tools --cache "$CACHE_DIR" \
      "@deveco/deveco-cli@$DEVECO_CLI_VERSION" )
fi

echo
echo "== DevEco toolchain =="
if bridge_studio_path >/dev/null; then
  bridge_require_studio
else
  cat <<'MSG'
DevEco Studio is NOT installed yet.

That is the current blocker for this project. Everything up to and including the
rewrite engine works without it, but no .hap can be built and no emulator can be
started until it is present:

  https://developer.huawei.com/consumer/en/download/

Download "DevEco Studio" for macOS (Apple Silicon), install it, launch it once,
then re-run this script. See docs/ARCHITECTURE.md for why this is the critical
path.
MSG
  exit 0
fi

echo
echo "== Next steps =="
cat <<'MSG'
1. scripts/set-devco-region-cn.sh   (needed once, with DevEco Studio closed)
   Without this the emulator only offers a watch profile. It unlocks phone,
   tablet, 2-in-1 and TV profiles.

2. scripts/create-emulator.sh
   Downloads a system image and starts a phone emulator. Several gigabytes.

3. bash scripts/dev-loop.sh build
   Produces the .hap once the ArkTS application exists.
MSG
