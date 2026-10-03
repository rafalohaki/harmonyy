#!/usr/bin/env bash
#
# Install DevEco Studio from a downloaded .dmg or .zip, and report the data
# directory name that the region switch needs.
#
# The last part is the reason this is a script rather than a drag-and-drop: the
# directory DevEco Studio keeps its configuration in is named after
# `dataDirectoryName` in product-info.json, which is NOT the IDE build number
# shown in the UI. Getting it wrong is the most common way the region switch
# silently edits the wrong file.
#
# Usage:
#   scripts/install-deveco.sh <installer.dmg|installer.zip> [--target <dir>]
#
# Default target is /Applications, which normally needs your permission.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"

TARGET="/Applications"
INSTALLER=""

while [ $# -gt 0 ]; do
  case "$1" in
    --target)
      TARGET="$2"
      shift 2
      ;;
    *)
      INSTALLER="$1"
      shift
      ;;
  esac
done

if [ -z "$INSTALLER" ]; then
  sed -n '2,18p' "$0"
  exit 1
fi

if [ ! -f "$INSTALLER" ]; then
  echo "Installer not found: $INSTALLER" >&2
  exit 1
fi

# Refuse to work from an incomplete download. A partially written archive is the
# single most common cause of a corrupt install.
case "$INSTALLER" in
  *.crdownload|*.download|*.part)
    echo "That is an incomplete download ($INSTALLER)." >&2
    echo "Wait until the browser has finished and renamed the file." >&2
    exit 1
    ;;
esac

mkdir -p "$TARGET"

report() {
  local app="$1"
  local info="$app/Contents/product-info.json"
  if [ ! -f "$info" ]; then
    info="$app/product-info.json"
  fi

  if [ ! -f "$info" ]; then
    echo "Installed to $app, but product-info.json was not found." >&2
    echo "Set DEVECO_CLI_STUDIO_PATH manually if devecocli cannot find it." >&2
    return
  fi

  echo
  echo "== installed =="
  echo "path              : $app"
  node -e '
    const fs = require("fs");
    const info = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    const dataDir = info.dataDirectoryName
      || ("DevEcoStudio" + String(info.version || "").split(".").slice(0, 2).join("."));
    console.log("name              : " + (info.name || "unknown"));
    console.log("version           : " + (info.version || "unknown"));
    console.log("dataDirectoryName : " + dataDir);
    console.log("");
    console.log("Region file the switch will edit:");
    console.log("  ~/Library/Application Support/Huawei/" + dataDir + "/options/country.region.xml");
  ' "$info"
  echo
  echo "Next: launch DevEco Studio once (it creates that file), close it, then run"
  echo "      scripts/set-devco-region-cn.sh"
}

case "$INSTALLER" in
  *.dmg)
    echo "== mounting =="
    MOUNT_POINT="$(hdiutil attach -nobrowse -readonly "$INSTALLER" \
      | grep -o '/Volumes/.*' | tail -1)"
    if [ -z "$MOUNT_POINT" ] || [ ! -d "$MOUNT_POINT" ]; then
      echo "Could not mount $INSTALLER" >&2
      exit 1
    fi
    echo "mounted at $MOUNT_POINT"

    APP_SRC="$(find "$MOUNT_POINT" -maxdepth 2 -name '*.app' -print | head -1)"
    if [ -z "$APP_SRC" ]; then
      echo "No .app found inside the disk image." >&2
      hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || true
      exit 1
    fi

    echo "== copying $(basename "$APP_SRC") to $TARGET =="
    rm -rf "$TARGET/$(basename "$APP_SRC")"
    cp -R "$APP_SRC" "$TARGET/"

    echo "== unmounting =="
    hdiutil detach "$MOUNT_POINT" >/dev/null

    report "$TARGET/$(basename "$APP_SRC")"
    ;;

  *.zip)
    echo "== unzipping to $TARGET =="
    unzip -q -o "$INSTALLER" -d "$TARGET"
    APP_SRC="$(find "$TARGET" -maxdepth 2 -name '*.app' -print -newer "$INSTALLER" | head -1)"
    if [ -z "$APP_SRC" ]; then
      APP_SRC="$(find "$TARGET" -maxdepth 2 -name 'DevEco*.app' -print | head -1)"
    fi
    if [ -z "$APP_SRC" ]; then
      echo "Unzipped, but no .app was found under $TARGET." >&2
      exit 1
    fi
    report "$APP_SRC"
    ;;

  *)
    echo "Unsupported installer type: $INSTALLER (expected .dmg or .zip)" >&2
    exit 1
    ;;
esac
