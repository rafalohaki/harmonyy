#!/usr/bin/env bash
#
# Switch DevEco Studio's region to CN.
#
# Why this is necessary: outside mainland China DevEco Studio only offers a smart
# watch emulator profile. With the region set to CN the device manager exposes
# phone, tablet, 2-in-1 and TV profiles as well.
#
# The setting lives in a country.region.xml file inside DevEco Studio's *data*
# directory, whose name is not the IDE build number. It comes from
# product-info.json ("dataDirectoryName"), for example DevEcoStudio6.1.
#
# DevEco Studio must be closed before this runs, otherwise it overwrites the file
# on exit.
#
# Usage:
#   scripts/set-devco-region-cn.sh [--dry-run]

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
fi

STUDIO_DIR="$(bridge_studio_path || true)"
if [ -z "$STUDIO_DIR" ]; then
  echo "DevEco Studio not found. Install it first (scripts/setup-toolchain.sh)." >&2
  exit 1
fi

PRODUCT_INFO="$STUDIO_DIR/product-info.json"
if [ ! -f "$PRODUCT_INFO" ]; then
  echo "product-info.json not found in $STUDIO_DIR" >&2
  exit 1
fi

# Prefer dataDirectoryName; fall back to major.minor from the version field.
DATA_DIR="$(node -e '
  const fs = require("fs");
  const info = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
  if (info.dataDirectoryName) { process.stdout.write(info.dataDirectoryName); }
  else {
    const parts = String(info.version || "").split(".");
    process.stdout.write("DevEcoStudio" + parts[0] + "." + parts[1]);
  }
' "$PRODUCT_INFO")"

if [ -z "$DATA_DIR" ]; then
  echo "Could not determine the DevEco Studio data directory name." >&2
  exit 1
fi

# Use the real home: DevEco Studio runs as a GUI and writes here.
OPTIONS_DIR="$BRIDGE_REAL_HOME/Library/Application Support/Huawei/$DATA_DIR/options"
REGION_FILE="$OPTIONS_DIR/country.region.xml"

echo "data directory : $DATA_DIR"
echo "region file    : $REGION_FILE"

if [ ! -f "$REGION_FILE" ]; then
  cat >&2 <<MSG
$REGION_FILE does not exist.

Launch DevEco Studio once and complete its first-launch setup, which creates its
configuration files, then close it and re-run this script.
MSG
  exit 1
fi

echo "current        : $(grep -o '<countryregion[^/]*/>' "$REGION_FILE" || echo 'not found')"

if grep -q 'name="CN"' "$REGION_FILE"; then
  echo "already set to CN; nothing to do."
  exit 0
fi

if [ "$DRY_RUN" = "1" ]; then
  echo "dry run: would rewrite <countryregion name="..."/> to CN"
  exit 0
fi

# Refuse to edit while the IDE is running: it would be overwritten on exit.
if pgrep -f "DevEco-Studio" >/dev/null 2>&1; then
  echo "DevEco Studio is running. Close it completely and re-run." >&2
  exit 1
fi

BACKUP="$REGION_FILE.bridge-backup"
if [ ! -f "$BACKUP" ]; then
  cp "$REGION_FILE" "$BACKUP"
  echo "backup         : $BACKUP"
fi

node -e '
  const fs = require("fs");
  const file = process.argv[1];
  let xml = fs.readFileSync(file, "utf8");
  if (/<countryregion[^>]*\/>/.test(xml)) {
    xml = xml.replace(/<countryregion[^>]*\/>/, "<countryregion name=\"CN\"/>");
  } else if (/<countryregion[^>]*>[\s\S]*?<\/countryregion>/.test(xml)) {
    xml = xml.replace(
      /<countryregion[^>]*>[\s\S]*?<\/countryregion>/,
      "<countryregion name=\"CN\"/>"
    );
  } else {
    console.error("countryregion element not found in " + file);
    process.exit(1);
  }
  fs.writeFileSync(file, xml);
' "$REGION_FILE"

echo "updated        : $(grep -o '<countryregion[^/]*/>' "$REGION_FILE")"
echo
echo "Start DevEco Studio again and confirm that the device manager now offers"
echo "phone, tablet, 2-in-1 and TV profiles."
