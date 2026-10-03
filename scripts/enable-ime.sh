#!/usr/bin/env bash
#
# Enable and switch to the Bridge keyboard on a connected device or emulator.
#
# The IME tool is supported since API 20, which is the hackathon minimum, so this
# is a reproducible scripted path rather than a manual journey through Settings.
# That matters twice over: the judges can reproduce it, and the demo can be
# driven from the command line.
#
# Usage:
#   scripts/enable-ime.sh <bundle-name> [--device <serial>]
#   scripts/enable-ime.sh --status
#
# Notes:
#   -e <bundle>      enable as an input method (without -b/-f it is basic mode)
#   -e <bundle> -f   enable in full experience mode
#   -s <bundle>      switch to it
#   -g               print the current input method
#   -l               list all input methods
# The preset default input method cannot be disabled, and switching is refused
# while the screen is locked or a password is being entered.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"

HDC="${BRIDGE_HDC:-hdc}"

DEVICE_ARGS=()
POSITIONAL=()
while [ $# -gt 0 ]; do
  case "$1" in
    --device)
      DEVICE_ARGS=(-t "$2")
      shift 2
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

if ! command -v "$HDC" >/dev/null 2>&1; then
  if [ -n "${DEVECO_CLI_STUDIO_PATH:-}" ]; then
    CANDIDATE="$DEVECO_CLI_STUDIO_PATH/sdk/default/openharmony/toolchains/hdc"
    if [ -x "$CANDIDATE" ]; then
      HDC="$CANDIDATE"
    fi
  fi
fi

if ! command -v "$HDC" >/dev/null 2>&1 && [ ! -x "$HDC" ]; then
  echo "hdc not found. Set BRIDGE_HDC to the hdc binary, or install DevEco Studio." >&2
  exit 1
fi

if [ "${POSITIONAL[0]:-}" = "--status" ] || [ $# -eq 0 -a "${POSITIONAL[0]:-}" = "--status" ]; then
  echo "== enabled input methods =="
  "$HDC" "${DEVICE_ARGS[@]}" shell ime -l || true
  echo
  echo "== current input method =="
  "$HDC" "${DEVICE_ARGS[@]}" shell ime -g || true
  exit 0
fi

BUNDLE="${POSITIONAL[0]:-}"
if [ -z "$BUNDLE" ]; then
  echo "Usage: scripts/enable-ime.sh <bundle-name> [--device <serial>]" >&2
  echo "       scripts/enable-ime.sh --status" >&2
  exit 1
fi

echo "== enabling $BUNDLE (full experience mode) =="
"$HDC" "${DEVICE_ARGS[@]}" shell ime -e "$BUNDLE" -f

echo "== switching to $BUNDLE =="
"$HDC" "${DEVICE_ARGS[@]}" shell ime -s "$BUNDLE"

echo "== verifying =="
CURRENT="$("$HDC" "${DEVICE_ARGS[@]}" shell ime -g || true)"
echo "current input method: $CURRENT"
case "$CURRENT" in
  *"$BUNDLE"*)
    echo "OK: $BUNDLE is the active input method."
    ;;
  *)
    echo "WARNING: the active input method does not look like $BUNDLE." >&2
    echo "Unlock the screen and make sure no password field is focused, then retry." >&2
    exit 1
    ;;
esac
