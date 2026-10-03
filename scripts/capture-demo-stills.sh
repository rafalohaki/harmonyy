#!/usr/bin/env bash
#
# Capture the demo video's source material from the emulator.
#
# The demo is assembled by Remotion, but every frame in it is a real device state:
# this script drives the emulator through the storyboard and captures each one. It
# exists so the video can be regenerated rather than being a one-off artefact.
#
# Deliberate design choices:
#   - snapshots come from the device (`snapshot_display`), not from a screen
#     recorder, so each captured state is exactly what the device rendered;
#   - the API key is already stored on the device and is never passed in here, so
#     this script is safe to publish and contains no secret;
#   - coordinates are read from `devecocli ui layout` rather than hard-coded,
#     because a tap at coordinates taken from a screenshot misses: the screenshot
#     is displayed scaled. Every automation step in this script lands first time
#     for that reason.
#
# Usage:
#   scripts/capture-demo-stills.sh            # capture everything
#   scripts/capture-demo-stills.sh --list     # show what would be captured

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"

CLI="$BRIDGE_CLI"
HDC="${BRIDGE_HDC:-/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc}"
DEVICE="${BRIDGE_DEVICE:-127.0.0.1:5555}"
BUNDLE="com.bridge.ime"
OUT="$BRIDGE_REPO_ROOT/demo/public/stills"
DEVICE_TMP="/data/local/tmp"

if [ ! -x "$CLI" ]; then
  echo "devecocli not found at $CLI; run scripts/setup-toolchain.sh" >&2
  exit 1
fi

if [ "${1:-}" = "--list" ]; then
  cat <<'MSG'
01-onboarding         the first screen: what Bridge is and how to turn it on
02-advanced-settings  endpoint, model and key, behind one labelled door
03-attached           the keyboard panel attached to an empty scratchpad
04-typed              deliberately broken Polish in the field
05-rewrite-variants   three variants returned by the model
06-rewrite-applied    the chosen variant replacing the field text
07-compose-picked     three concepts picked in the strip
08-compose-variants   a grammatical sentence composed from them
09-compose-applied    the composed sentence sitting in the field
10-pii-hidden         e-mail and phone redacted on-device, values restored
11-offline-only       the offline switch degrading honestly, with the reason
12-in-another-app     rewrite in the Huawei browser's own field (captured manually)
MSG
  exit 0
fi

mkdir -p "$OUT"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Bounds of the first node whose label starts with the given text, as
# "x1,y1,x2,y2". A prefix match is deliberate: some labels are dynamic, so the
# compose button reads "Compose" before anything is picked and "Compose (3)"
# afterwards, and an exact match silently found nothing.
node_bounds() {
  local label="$1"
  "$CLI" ui layout --all-windows 2>/dev/null \
    | grep -oE "(TextInput|TextArea|Button|Toggle) \[[0-9]+,[0-9]+,[0-9]+,[0-9]+\]( \"[^\"]*\")?" \
    | grep -F "\"$label" \
    | head -1 \
    | grep -oE "[0-9]+,[0-9]+,[0-9]+,[0-9]+"
}

# Bounds of the first node of a given type, ignoring the label.
type_bounds() {
  local type="$1"
  "$CLI" ui layout --all-windows 2>/dev/null \
    | grep -oE "$type \[[0-9]+,[0-9]+,[0-9]+,[0-9]+\]" \
    | head -1 \
    | grep -oE "[0-9]+,[0-9]+,[0-9]+,[0-9]+"
}

centre() {
  echo "$1" | awk -F, '{print int(($1+$3)/2), int(($2+$4)/2)}'
}

# A missing node is logged and skipped rather than aborting the run: a capture
# that gets nine of ten states is worth more than one that stops at the first
# surprise, and the log says which is missing.
tap_bounds() {
  local what="$1"
  local bounds="$2"
  if [ -z "$bounds" ]; then
    echo "  ! $what not found; skipping" >&2
    return 0
  fi
  read -r x y <<< "$(centre "$bounds")"
  "$CLI" ui click "$x" "$y" >/dev/null 2>&1
  sleep 1
}

tap_label() {
  tap_bounds "$1" "$(node_bounds "$1")"
}

# A concept tile is a Column containing two Text nodes, so it has no label of its
# own. Tapping the word's coordinates still lands inside the Column, which is what
# carries the onClick.
text_bounds() {
  local label="$1"
  "$CLI" ui layout --all-windows 2>/dev/null \
    | grep -oE "Text \[[0-9]+,[0-9]+,[0-9]+,[0-9]+\] \"[^\"]*\"" \
    | grep -F "\"$label" \
    | head -1 \
    | grep -oE "[0-9]+,[0-9]+,[0-9]+,[0-9]+"
}

tap_text() {
  tap_bounds "$1" "$(text_bounds "$1")"
}

# The first variant card. Its bounds are the card itself, so the centre is the
# target; no offset guessing.
tap_first_variant() {
  tap_bounds "first variant card" "$(type_bounds Column)"
}

# The emulator dims after 30 seconds of inactivity and locks, which silently
# produces blank frames and makes every tap miss. Both happened during the first
# capture run: nine stills were taken and one scene failed with "scratchpad not
# found" because the screen had gone to sleep, not because the UI was wrong.
# So every scene starts here.
ensure_ready() {
  local state
  state="$("$HDC" -t "$DEVICE" shell "hidumper -s PowerManagerService -a -s" 2>/dev/null \
    | grep -m1 'Current State' | awk '{print $NF}')"
  if [ "$state" != "AWAKE" ]; then
    "$HDC" -t "$DEVICE" shell "power-shell wakeup" >/dev/null 2>&1
    sleep 2
  fi

  # Keep it awake for the whole run rather than fighting the timeout per scene.
  "$HDC" -t "$DEVICE" shell "power-shell timeout -o 1800000" >/dev/null 2>&1

  # The scratchpad is the one node every scene depends on, so its absence means
  # either a locked screen or a backgrounded app; both are recoverable.
  local attempt
  for attempt in 1 2; do
    if "$CLI" ui layout --all-windows 2>/dev/null | grep -q "TextArea"; then
      return 0
    fi
    echo "  (screen locked or app backgrounded; recovery attempt $attempt)" >&2
    # Dismiss the lock screen, then bring the app forward. A swipe can land on the
    # system keyboard's own window, so the explicit start afterwards matters.
    "$CLI" ui swipe 660 2400 660 1000 >/dev/null 2>&1
    sleep 3
    "$HDC" -t "$DEVICE" shell aa start -b "$BUNDLE" -a EntryAbility >/dev/null 2>&1
    sleep 7
  done
}

# Focus the scratchpad by geometry: it is the only TextArea on the settings page.
focus_scratchpad() {
  ensure_ready
  tap_bounds "scratchpad" "$(type_bounds TextArea)"
}

# A cold start empties the scratchpad, because its contents are @State and are
# deliberately not persisted.
clear_scratchpad() {
  "$HDC" -t "$DEVICE" shell aa force-stop "$BUNDLE" >/dev/null 2>&1
  sleep 2
  "$HDC" -t "$DEVICE" shell aa start -b "$BUNDLE" -a EntryAbility >/dev/null 2>&1
  sleep 6
}

save_settings() {
  tap_label "Save"
  sleep 3
}

# Capture the device screen to the output directory.
snap() {
  local name="$1"
  ensure_ready
  local remote="$DEVICE_TMP/demo-$name.jpeg"
  "$HDC" -t "$DEVICE" shell "snapshot_display -t jpeg -f $remote" >/dev/null 2>&1
  "$HDC" -t "$DEVICE" file recv "$remote" "$OUT/$name.jpeg" >/dev/null 2>&1
  if [ -s "$OUT/$name.jpeg" ]; then
    echo "  captured $name"
  else
    # Log it and carry on. One missing frame must not abort the run: nine of ten
    # states is worth more than none, and the log names the missing one.
    echo "  FAILED to capture $name" >&2
  fi
}

# ---------------------------------------------------------------------------
# The storyboard
# ---------------------------------------------------------------------------

echo "device   : $DEVICE"
echo "output   : $OUT"
echo

# ---------------------------------------------------------------------------
# Preflight: the endpoint must be the working one.
#
# The first runs of this script were poisoned by a leftover unreachable endpoint
# from a previous failed run, which turned the "model returns variants" scene into
# an offline scene without any error. A capture that silently records the wrong
# state is worse than one that fails, so the configuration is checked up front.
# ---------------------------------------------------------------------------
echo "== preflight: configuration =="
"$HDC" -t "$DEVICE" shell "power-shell wakeup" >/dev/null 2>&1
"$HDC" -t "$DEVICE" shell "power-shell timeout -o 86400000" >/dev/null 2>&1
"$HDC" -t "$DEVICE" shell aa start -b "$BUNDLE" -a EntryAbility >/dev/null 2>&1
sleep 7

# The endpoint lives on the Advanced settings screen since the first screen became
# an explanation of the product. Check it there, fix it there, come back.
tap_label "Advanced settings"
sleep 2

BASE_NOW="$("$CLI" ui layout --all-windows 2>/dev/null \
  | grep -oE 'TextInput \[[0-9]+,[0-9]+,[0-9]+,[0-9]+\] "[^"]*"' | head -1 \
  | sed 's/.*"\(.*\)"$/\1/')" || true
echo "endpoint: ${BASE_NOW:-<not on screen>}"

if [ "$BASE_NOW" != "https://api.groq.com/openai/v1" ]; then
  echo "  restoring it, so the model scenes capture the model"
  ENDPOINT="$(type_bounds TextInput)"
  tap_label "Clear"
  if [ -n "$ENDPOINT" ]; then
    read -r px py <<< "$(centre "$ENDPOINT")"
    "$CLI" ui text "https://api.groq.com/openai/v1" "$px" "$py" >/dev/null 2>&1
    sleep 2
    save_settings
  fi
fi

tap_label "Back"
sleep 2
echo

echo "== 01 the first screen: what Bridge is =="
"$HDC" -t "$DEVICE" shell ime -s "$BUNDLE" >/dev/null 2>&1 || true
clear_scratchpad
snap 01-onboarding

echo "== 02 configuration, behind one labelled door =="
tap_label "Advanced settings"
sleep 2
snap 02-advanced-settings
tap_label "Back"
sleep 2

echo "== 03 attached to an empty field =="
focus_scratchpad
sleep 2
snap 03-attached

echo "== 04 deliberately broken Polish =="
SCRATCH="$(type_bounds TextArea)"
read -r sx sy <<< "$(centre "$SCRATCH")"
"$CLI" ui text "ja chciec jutro przyjsc na spotkanie o 10" "$sx" "$sy" >/dev/null 2>&1
sleep 3
snap 04-typed

echo "== 05 the model's variants =="
tap_label "Correct"
# The remote call has taken 0.8-8.9 s in observed runs, depending on input; wait
# past the worst of it.
sleep 12
snap 05-rewrite-variants

echo "== 06 the chosen variant applied =="
tap_first_variant
sleep 3
snap 06-rewrite-applied

echo "== 07 concepts picked =="
clear_scratchpad
focus_scratchpad
sleep 2
# Three concept buttons, addressed by their labels so a layout change cannot
# silently tap the wrong one.
tap_text "jeść"
tap_text "później"
tap_text "rodzina"
sleep 2
snap 07-compose-picked

echo "== 08 the composed sentence =="
tap_label "Compose"
sleep 12
snap 08-compose-variants

echo "== 09 the composed sentence applied =="
tap_first_variant
sleep 3
snap 09-compose-applied

echo "== 10 personal data withheld =="
# An e-mail and a phone number, so the on-device scrubber has something to hold
# back: the request carries placeholders and the variants get the values back.
clear_scratchpad
focus_scratchpad
SCRATCH="$(type_bounds TextArea)"
read -r sx sy <<< "$(centre "$SCRATCH")"
"$CLI" ui text "napisz do jan.kowalski@example.com albo zadzwon +48 123 456 789" "$sx" "$sy" >/dev/null 2>&1
sleep 3
tap_label "Correct"
sleep 12
snap 10-pii-hidden

echo "== 11 degrading honestly, with the reason shown =="
# The offline-only switch, rather than an unreachable endpoint: reproducible, and
# it leaves no broken configuration behind. The switch lives on the Advanced
# screen, so this scene goes there and comes back.
clear_scratchpad
tap_label "Advanced settings"
sleep 2
tap_bounds "offline-only switch" "$(type_bounds Toggle)"
save_settings
tap_label "Back"
sleep 2
focus_scratchpad
SCRATCH="$(type_bounds TextArea)"
read -r sx sy <<< "$(centre "$SCRATCH")"
"$CLI" ui text "ja chciec isc do domu" "$sx" "$sy" >/dev/null 2>&1
sleep 3
tap_label "Correct"
sleep 12
snap 11-offline-only

echo
echo "== restoring the working state =="
# Scene 11 leaves the offline-only switch on, which would silently make every later
# run an offline run. Put it back. The endpoint is never corrupted by this
# storyboard, and the preflight checks it at the start of the next run anyway.
tap_label "Advanced settings"
sleep 2
tap_bounds "offline-only switch" "$(type_bounds Toggle)"
save_settings
tap_label "Back"
sleep 2

echo
echo "captured $(ls -1 "$OUT"/*.jpeg 2>/dev/null | wc -l | tr -d ' ') stills into $OUT"
