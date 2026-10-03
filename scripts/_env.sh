#!/usr/bin/env bash
#
# Shared environment for Bridge scripts.
#
# Toolchain state is kept repo-local by default so that a fresh checkout can be
# reproduced without polluting the machine. Set BRIDGE_HOME_OVERRIDE=0 to use the
# real HOME instead, which is what you want if DevEco Studio (running as a GUI,
# with the real HOME) is the thing that downloaded the emulator images.
#
# shellcheck shell=bash

set -euo pipefail

BRIDGE_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export BRIDGE_REPO_ROOT

# The real user home, before any override. Scripts that must reach DevEco
# Studio's own configuration (for example the region switch) use this.
export BRIDGE_REAL_HOME="${BRIDGE_REAL_HOME:-$HOME}"

BRIDGE_HOME_OVERRIDE="${BRIDGE_HOME_OVERRIDE:-0}"
if [ "$BRIDGE_HOME_OVERRIDE" = "1" ]; then
  export HOME="$BRIDGE_REPO_ROOT/.home"
  mkdir -p "$HOME"
fi
export BRIDGE_HOME_OVERRIDE

# Locally installed DevEco CLI.
export BRIDGE_CLI="$BRIDGE_REPO_ROOT/.tools/node_modules/.bin/devecocli"

bridge_require_cli() {
  if [ ! -x "$BRIDGE_CLI" ]; then
    echo "devecocli is not installed yet. Run scripts/setup-toolchain.sh first." >&2
    exit 1
  fi
}

# Locate the DevEco Studio installation so devecocli can find the toolchain.
bridge_studio_path() {
  if [ -n "${DEVECO_CLI_STUDIO_PATH:-}" ]; then
    echo "$DEVECO_CLI_STUDIO_PATH"
    return 0
  fi
  if [ -d "/Applications/DevEco-Studio.app" ]; then
    echo "/Applications/DevEco-Studio.app/Contents"
    return 0
  fi
  return 1
}

bridge_require_studio() {
  local path
  if ! path="$(bridge_studio_path)"; then
    cat >&2 <<'MSG'
DevEco Studio was not found.

devecocli is only a wrapper around the real toolchain (hvigor, ohpm, hdc,
clangd). It needs either DevEco Studio or the standalone Command Line Tools:

  1. Download DevEco Studio for macOS (Apple Silicon) from
     https://developer.huawei.com/consumer/en/download/
  2. Install it and launch it once so it writes its configuration files.
  3. Re-run this script.

If you installed it somewhere unusual, export DEVECO_CLI_STUDIO_PATH to the
directory that contains product-info.json, and re-run. Alternatively export
DEVECO_CLI_CLT_PATH to a Command Line Tools installation.
MSG
    exit 1
  fi
  export DEVECO_CLI_STUDIO_PATH="$path"
  echo "DevEco Studio: $path"
}
