#!/usr/bin/env bash
#
# The inner development loop, scripted so that every claim in the README can be
# reproduced by someone else and so that the demo is repeatable.
#
# Usage:
#   scripts/dev-loop.sh tests                 # engine tests + reference checks (no SDK needed)
#   scripts/dev-loop.sh refs                  # static import/resource check only
#   scripts/dev-loop.sh engine                # exercise the engine, mock model, no credentials
#   scripts/dev-loop.sh lint                  # ArkTS static checks
#   scripts/dev-loop.sh build                 # produce the .hap
#   scripts/dev-loop.sh run                   # build, install and launch
#   scripts/dev-loop.sh logs                  # stream application logs
#   scripts/dev-loop.sh shot <name>           # emulator screenshot into docs/evidence/
#   scripts/dev-loop.sh ui                    # dump the current UI layout
#
# Everything except `tests` and `refs` requires the toolchain and a running emulator.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"

APP_DIR="$BRIDGE_REPO_ROOT/app"
EVIDENCE_DIR="$BRIDGE_REPO_ROOT/docs/evidence"

cmd="${1:-}"
shift || true

require_app_dir() {
  if [ ! -d "$APP_DIR" ]; then
    echo "The ArkTS application does not exist yet at $APP_DIR." >&2
    echo "It is created once DevEco Studio and the SDK are installed." >&2
    exit 1
  fi
}

case "$cmd" in
  tests)
    echo "== engine unit tests =="
    cd "$BRIDGE_REPO_ROOT"
    node --test core/test/
    echo
    echo "== static reference check =="
    node "$BRIDGE_REPO_ROOT/scripts/check-refs.mjs"
    echo
    echo "== secret check =="
    bash "$BRIDGE_REPO_ROOT/scripts/check-secrets.sh"
    ;;

  secrets)
    bash "$BRIDGE_REPO_ROOT/scripts/check-secrets.sh"
    ;;

  refs)
    echo "== static reference check =="
    node "$BRIDGE_REPO_ROOT/scripts/check-refs.mjs"
    ;;

  engine)
    echo "== engine playground (mock model, no credentials) =="
    node "$BRIDGE_REPO_ROOT/scripts/try-engine.mjs" --mock
    ;;

  lint)
    bridge_require_cli
    bridge_require_studio
    require_app_dir
    cd "$APP_DIR"
    "$BRIDGE_CLI" check lint
    ;;

  build)
    bridge_require_cli
    bridge_require_studio
    require_app_dir
    cd "$APP_DIR"
    # A successful build must be proven by the exit code and by the artefact,
    # not by a success message.
    "$BRIDGE_CLI" build
    echo
    echo "== unsigned artefacts =="
    find "$APP_DIR" -name '*.hap' -not -name '*signed*' -print
    ;;

  run)
    bridge_require_cli
    bridge_require_studio
    require_app_dir
    cd "$APP_DIR"
    "$BRIDGE_CLI" run
    ;;

  logs)
    bridge_require_cli
    bridge_require_studio
    "$BRIDGE_CLI" log
    ;;

  shot)
    bridge_require_cli
    bridge_require_studio
    name="${1:-screenshot}"
    mkdir -p "$EVIDENCE_DIR"
    out="$EVIDENCE_DIR/$name.png"
    "$BRIDGE_CLI" ui screenshot --output "$out" || "$BRIDGE_CLI" ui screenshot
    echo "saved: $out"
    ;;

  ui)
    bridge_require_cli
    bridge_require_studio
    "$BRIDGE_CLI" ui layout
    ;;

  *)
    sed -n '2,20p' "$0"
    exit 1
    ;;
esac
