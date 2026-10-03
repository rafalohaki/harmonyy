#!/usr/bin/env bash
#
# Fetch the Full OpenHarmony SDK for macOS on Apple Silicon from the public
# OpenHarmony mirror.
#
# Why this exists as a separate path: the SDK Manager inside DevEco Studio needs a
# signed-in Huawei account, while Huawei also publishes the same class of archive
# on a public mirror with no login. Having a second path removes a dependency that
# can block a build for hours when an account is still being activated.
#
# L2-SDK means the Full SDK, which includes system APIs that the public SDK omits.
# MAC-M1 means macOS on Apple Silicon.
#
# The archive is 1.2 GB, so the download resumes rather than restarting.
#
# Usage:
#   scripts/fetch-public-sdk.sh                    # default release (6.1, API 23)
#   scripts/fetch-public-sdk.sh --release 7.0-Release
#   scripts/fetch-public-sdk.sh --release 6.0-Release
#   scripts/fetch-public-sdk.sh --verify-only
#
# Releases and API levels, verified against the mirror:
#   6.0-Release  API 20
#   6.1-Release  API 23   <- matches this project's compileSdkVersion
#   7.0-Release  API 24   <- matches this project's targetSdkVersion

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"

MIRROR="https://repo.huaweicloud.com/openharmony/os"
RELEASE="6.1-Release"
ARCHIVE="L2-SDK-MAC-M1-PUBLIC.tar.gz"
DEST_DIR="$BRIDGE_REPO_ROOT/.downloads"
VERIFY_ONLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --release)
      RELEASE="$2"
      shift 2
      ;;
    --verify-only)
      VERIFY_ONLY=1
      shift
      ;;
    --help|-h)
      sed -n '2,30p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

BASE_URL="$MIRROR/$RELEASE"
OUT="$DEST_DIR/$ARCHIVE"
SUM="$OUT.sha256"

mkdir -p "$DEST_DIR"

verify() {
  if [ ! -f "$OUT" ]; then
    echo "Nothing to verify: $OUT does not exist." >&2
    return 1
  fi
  if [ ! -f "$SUM" ]; then
    echo "No checksum sidecar at $SUM; cannot verify." >&2
    return 1
  fi

  # The published sidecar lists the file name and its digest. Compare only the
  # digest so that a differing file name in the sidecar does not cause a false
  # failure.
  local expected actual
  expected="$(awk '{print $1}' "$SUM" | head -1 | tr 'A-Z' 'a-z')"
  actual="$(shasum -a 256 "$OUT" | awk '{print $1}')"

  if [ "$expected" = "$actual" ]; then
    echo "checksum OK: $actual"
  else
    echo "CHECKSUM MISMATCH" >&2
    echo "  expected $expected" >&2
    echo "  actual   $actual" >&2
    return 1
  fi
}

if [ "$VERIFY_ONLY" = "1" ]; then
  verify
  exit $?
fi

echo "release : $RELEASE"
echo "archive : $ARCHIVE"
echo "from    : $BASE_URL"
echo "into    : $OUT"
echo

echo "== checksum sidecar =="
curl -fL --retry 3 --retry-delay 5 -o "$SUM" "$BASE_URL/$ARCHIVE.sha256"
echo "downloaded $SUM"
echo

echo "== SDK archive (resumes if a partial file exists) =="
curl -fL --retry 3 --retry-delay 5 -C - -o "$OUT" "$BASE_URL/$ARCHIVE"

echo
echo "== verification =="
verify

echo
echo "size: $(du -h "$OUT" | awk '{print $1}')"
cat <<MSG

Next: inspect the real archive layout before placing anything.

  tar -tzf "$OUT" | head -40

Do not guess the expected directory structure. The archive is the authority; the
placement instructions in docs/SETUP.md are written once its structure is known.
MSG
