#!/usr/bin/env bash
#
# Create and start a phone emulator, then confirm it is reachable over hdc.
#
# The system image is several gigabytes, so this is the slow step. It is also the
# step the organisers single out: get the install path working early, because a
# submission that never reached a device scores nothing for demonstration.
#
# Usage:
#   scripts/create-emulator.sh            # image download + create + start
#   scripts/create-emulator.sh --list     # show what already exists

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"
bridge_require_cli
bridge_require_studio

if [ "${1:-}" = "--list" ]; then
  echo "== installed images =="
  "$BRIDGE_CLI" emulator image list || true
  echo
  echo "== emulator instances =="
  "$BRIDGE_CLI" emulator list || true
  exit 0
fi

echo "== Accepting the emulator licence if needed =="
"$BRIDGE_CLI" emulator license view >/dev/null 2>&1 || true

echo
echo "== Available system images =="
"$BRIDGE_CLI" emulator image list || true

cat <<'MSG'

If no image is listed, download one now, for example:

  devecocli emulator image download <image-id>

Then create and start a phone emulator:

  devecocli emulator create --name bridge-phone --device-type phone --image <image-id>
  devecocli emulator start bridge-phone

Finally confirm the device is visible:

  devecocli device list
MSG
