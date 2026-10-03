#!/usr/bin/env bash
#
# Sign the unsigned HAP offline with the Full OpenHarmony SDK's public
# development identity.
#
# Why this exists: `devecocli signature generate` is documented as
# region-restricted outside mainland China, and the organisers' recommendation is
# to sign through the DevEco Studio GUI. That would put a Huawei account and a
# manual GUI step on the critical path. The Full SDK ships everything needed to
# sign locally instead: hap-sign-tool.jar, the OpenHarmony.p12 development
# keystore, the profile-signing certificate and the profile template.
#
# This produces an ORDINARY application profile:
#   app-feature          hos_normal_app   (the template default; the organisers'
#                                          system-app helper overrides this to
#                                          hos_system_app, which we do not need)
#   apl                  normal
#   acls                 none
# The app requests only ohos.permission.INTERNET, which is an ordinary permission.
#
# The recipe follows the same five steps as the organisers' system-app helper, so
# the crypto is not invented here: export the CAs, issue an app certificate chain,
# build and sign the profile, then sign the HAP.
#
# Usage:
#   scripts/sign-hap.sh [<unsigned.hap>] [--work-dir <dir>] [--output <signed.hap>]
#
# Defaults to the debug artefact produced by `scripts/dev-loop.sh build`.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"

APP_DIR="$BRIDGE_REPO_ROOT/app"
DEFAULT_HAP="$APP_DIR/entry/build/default/outputs/default/entry-default-unsigned.hap"

HAP=""
OUTPUT=""
WORK_DIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --work-dir) WORK_DIR="$2"; shift 2 ;;
    --output)   OUTPUT="$2"; shift 2 ;;
    --help|-h)  sed -n '2,30p' "$0"; exit 0 ;;
    *)          HAP="$1"; shift ;;
  esac
done

HAP="${HAP:-$DEFAULT_HAP}"
WORK_DIR="${WORK_DIR:-$APP_DIR/.signing}"
OUTPUT="${OUTPUT:-$WORK_DIR/entry-default-signed.hap}"

if [ ! -f "$HAP" ]; then
  echo "Unsigned HAP not found: $HAP" >&2
  echo "Build it first: scripts/dev-loop.sh build" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Locate the SDK's signing material
# ---------------------------------------------------------------------------
find_sdk_lib() {
  local candidates=(
    "/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/lib"
    "$BRIDGE_REPO_ROOT/.downloads/sdk/ohos-sdk/toolchains/lib"
  )
  for dir in "${candidates[@]}"; do
    if [ -f "$dir/hap-sign-tool.jar" ] \
      && [ -f "$dir/OpenHarmony.p12" ] \
      && [ -f "$dir/OpenHarmonyProfileRelease.pem" ] \
      && [ -f "$dir/UnsgnedReleasedProfileTemplate.json" ]; then
      echo "$dir"
      return 0
    fi
  done
  return 1
}

if ! SDK_LIB="$(find_sdk_lib)"; then
  cat >&2 <<'MSG'
Could not find the SDK signing material.

Looked for hap-sign-tool.jar, OpenHarmony.p12, OpenHarmonyProfileRelease.pem and
UnsgnedReleasedProfileTemplate.json in:
  /Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/lib
  <repo>/.downloads/sdk/ohos-sdk/toolchains/lib

Install DevEco Studio, or fetch the Full SDK with scripts/fetch-public-sdk.sh.
MSG
  exit 1
fi

# ---------------------------------------------------------------------------
# Locate java and keytool. DevEco Studio ships a JBR; a system JDK also works.
# ---------------------------------------------------------------------------
find_tool() {
  local name="$1"
  local jbr="/Applications/DevEco-Studio.app/Contents/jbr/Contents/Home/bin/$name"
  if [ -x "$jbr" ]; then echo "$jbr"; return 0; fi
  if command -v "$name" >/dev/null 2>&1; then command -v "$name"; return 0; fi
  return 1
}

if ! JAVA="$(find_tool java)"; then
  echo "java not found. Install a JDK or DevEco Studio." >&2
  exit 1
fi
if ! KEYTOOL="$(find_tool keytool)"; then
  echo "keytool not found. A JRE alone is not enough; install a JDK." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Read the project identity
# ---------------------------------------------------------------------------
BUNDLE_NAME="$(python3 -c '
import json,re,sys
raw=open(sys.argv[1],encoding="utf-8").read()
raw=re.sub(r"//[^\n]*","",raw)
d=json.loads(raw)
print(d["app"]["bundleName"])
' "$APP_DIR/AppScope/app.json5")"

# The profile wants a numeric API level. build-profile uses labels like
# "6.0.0(20)", so extract the number in parentheses.
COMPATIBLE_VERSION="$(python3 -c '
import re,sys
raw=open(sys.argv[1],encoding="utf-8").read()
raw=re.sub(r"//[^\n]*","",raw)
# The key itself is quoted, so allow a closing quote before the colon: the line
# looks like  "compatibleSdkVersion": "6.0.0(20)",
m=re.search(r"compatibleSdkVersion\"?\s*:\s*\"?([0-9]+(?:\.[0-9]+)*)(?:\((\d+)\))?",raw)
if not m: sys.exit("compatibleSdkVersion not found in build-profile.json5")
print(m.group(2) if m.group(2) else m.group(1))
' "$APP_DIR/build-profile.json5")"

STORE_PASSWORD="${OHOS_STORE_PASSWORD:-123456}"
KEY_PASSWORD="${OHOS_KEY_PASSWORD:-$STORE_PASSWORD}"
VALIDITY_DAYS="${OHOS_VALIDITY_DAYS:-1095}"

echo "sdk lib           : $SDK_LIB"
echo "java              : $JAVA"
echo "bundle name       : $BUNDLE_NAME"
echo "compatible API    : $COMPATIBLE_VERSION"
echo "unsigned hap      : $HAP"
echo "work dir          : $WORK_DIR"
echo "output            : $OUTPUT"
echo

mkdir -p "$WORK_DIR"

ROOT_CA="$WORK_DIR/OpenHarmonyApplicationRootCA.cer"
APP_CA="$WORK_DIR/OpenHarmonyApplicationCA.cer"
APP_CHAIN="$WORK_DIR/BridgeApplication.cer"
PROFILE_JSON="$WORK_DIR/bridge-profile.json"
SIGNED_PROFILE="$WORK_DIR/bridge-profile.p7b"
PROFILE_VERIFICATION="$WORK_DIR/bridge-profile-verification.json"
VERIFIED_CHAIN="$WORK_DIR/verified-app-cert.cer"
EMBEDDED_PROFILE="$WORK_DIR/verified-embedded-profile.p7b"
EMBEDDED_VERIFICATION="$WORK_DIR/verified-embedded-profile.json"

echo "== 1/5 exporting the development CA certificates =="
"$KEYTOOL" -exportcert -alias 'openharmony application root ca' \
  -keystore "$SDK_LIB/OpenHarmony.p12" -storepass "$STORE_PASSWORD" -file "$ROOT_CA"
"$KEYTOOL" -exportcert -alias 'openharmony application ca' \
  -keystore "$SDK_LIB/OpenHarmony.p12" -storepass "$STORE_PASSWORD" -file "$APP_CA"

echo
echo "== 2/5 issuing an application certificate chain =="
CERT_CN="$(printf '%s' "$BUNDLE_NAME" | tr -c 'A-Za-z0-9._-' '_' | cut -c1-64)"
"$JAVA" -jar "$SDK_LIB/hap-sign-tool.jar" generate-app-cert \
  -keyAlias 'openharmony application release' \
  -keyPwd "$KEY_PASSWORD" \
  -issuer 'C=CN,O=OpenHarmony,OU=OpenHarmony Team,CN=OpenHarmony Application CA' \
  -issuerKeyAlias 'openharmony application ca' \
  -issuerKeyPwd "$STORE_PASSWORD" \
  -subject "C=CN,O=OpenHarmony,OU=OpenHarmony Team,CN=$CERT_CN" \
  -validity "$VALIDITY_DAYS" \
  -signAlg SHA256withECDSA \
  -rootCaCertFile "$ROOT_CA" \
  -subCaCertFile "$APP_CA" \
  -keystoreFile "$SDK_LIB/OpenHarmony.p12" \
  -keystorePwd "$STORE_PASSWORD" \
  -outForm certChain \
  -outFile "$APP_CHAIN"

echo
echo "== 3/5 building the ordinary-application profile =="
python3 - "$SDK_LIB/UnsgnedReleasedProfileTemplate.json" "$PROFILE_JSON" \
  "$BUNDLE_NAME" "$APP_CHAIN" "$APP_DIR/AppScope/app.json5" "$VALIDITY_DAYS" <<'PY'
import json, re, sys, time, uuid

template, out, bundle, chain_file, app_json, validity_days = sys.argv[1:7]

def strip_comments(text):
    return re.sub(r"//[^\n]*", "", text)

profile = json.load(open(template, encoding="utf-8"))
app = json.loads(strip_comments(open(app_json, encoding="utf-8").read()))

chain = open(chain_file, encoding="utf-8").read()
blocks = re.findall(
    r"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----", chain, re.S)
if not blocks:
    sys.exit("no certificate found in the generated chain")

now = int(time.time())
profile["version-name"] = app["app"].get("versionName", "1.0.0")
profile["version-code"] = app["app"].get("versionCode", 1)
profile["uuid"] = str(uuid.uuid4())
profile["validity"] = {
    "not-before": now - 300,
    "not-after": now + int(validity_days) * 86400,
}
profile["type"] = "release"
profile["bundle-info"]["bundle-name"] = bundle
# Leave the template's own identity alone. It is already an ordinary application:
#   "apl": "normal", "app-feature": "hos_normal_app"
# That is precisely what we want, and the organisers' helper overrides both to
# system-app values we have no use for.
# Match the organisers' helper exactly: trim the leaf and append one newline.
# The tool is sensitive to the trailing newline of this PEM field.
profile["bundle-info"]["distribution-certificate"] = blocks[0].strip() + "\n"
profile["acls"] = {"allowed-acls": []}

json.dump(profile, open(out, "w", encoding="utf-8"), indent=2)
print("app-feature       :", profile["bundle-info"].get("app-feature"))
print("apl               :", profile["bundle-info"].get("apl"))
print("allowed-acls      :", profile["acls"]["allowed-acls"])
PY

echo
echo "== 4/5 signing and verifying the profile =="
"$JAVA" -jar "$SDK_LIB/hap-sign-tool.jar" sign-profile \
  -mode localSign \
  -keyAlias 'openharmony application profile release' \
  -keyPwd "$KEY_PASSWORD" \
  -profileCertFile "$SDK_LIB/OpenHarmonyProfileRelease.pem" \
  -inFile "$PROFILE_JSON" \
  -signAlg SHA256withECDSA \
  -keystoreFile "$SDK_LIB/OpenHarmony.p12" \
  -keystorePwd "$STORE_PASSWORD" \
  -outFile "$SIGNED_PROFILE"

"$JAVA" -jar "$SDK_LIB/hap-sign-tool.jar" verify-profile \
  -inFile "$SIGNED_PROFILE" \
  -outFile "$PROFILE_VERIFICATION"

echo
echo "== 5/5 signing and verifying the HAP =="
"$JAVA" -jar "$SDK_LIB/hap-sign-tool.jar" sign-app \
  -mode localSign \
  -keyAlias 'openharmony application release' \
  -keyPwd "$KEY_PASSWORD" \
  -appCertFile "$APP_CHAIN" \
  -profileFile "$SIGNED_PROFILE" \
  -profileSigned 1 \
  -inFile "$HAP" \
  -signAlg SHA256withECDSA \
  -keystoreFile "$SDK_LIB/OpenHarmony.p12" \
  -keystorePwd "$STORE_PASSWORD" \
  -outFile "$OUTPUT" \
  -compatibleVersion "$COMPATIBLE_VERSION" \
  -signCode 1

# Four independent gates, as the organisers' skill insists: do not report success
# from a build or an install message alone.
"$JAVA" -jar "$SDK_LIB/hap-sign-tool.jar" verify-app \
  -inFile "$OUTPUT" \
  -outCertChain "$VERIFIED_CHAIN" \
  -outProfile "$EMBEDDED_PROFILE"

"$JAVA" -jar "$SDK_LIB/hap-sign-tool.jar" verify-profile \
  -inFile "$EMBEDDED_PROFILE" \
  -outFile "$EMBEDDED_VERIFICATION"

python3 - "$EMBEDDED_VERIFICATION" "$BUNDLE_NAME" "$OUTPUT" <<'PY'
import hashlib, json, re, sys

verification, expected_bundle, hap = sys.argv[1:4]
raw = open(verification, encoding="utf-8").read()
data = json.loads(re.sub(r"//[^\n]*", "", raw))

# Verified shape of the tool's output:
#   { "verifiedPassed": true, "message": "OK",
#     "content": { "bundle-info": { "bundle-name": ..., "apl": ..., "app-feature": ... } } }
if data.get("verifiedPassed") is False:
    sys.exit(f"embedded profile verification failed: {data.get('message')}")
info = (data.get("content") or {}).get("bundle-info") or {}
bundle = info.get("bundle-name")
feature = info.get("app-feature")
apl = info.get("apl")

if bundle != expected_bundle:
    sys.exit(f"embedded profile bundle mismatch: {bundle} != {expected_bundle}")
if feature != "hos_normal_app":
    sys.exit(f"embedded profile is not an ordinary app: {feature}")

blob = open(hap, "rb").read()
digest = hashlib.sha256(blob).hexdigest()
print(f"signed hap        : {hap}")
print(f"size              : {len(blob)/1048576:.2f} MB")
print(f"sha256            : {digest}")
print(f"bundle-name       : {bundle}")
print(f"app-feature       : {feature}")
print(f"apl               : {apl}")
PY

echo
echo "OK: signed as an ordinary application. Install with:"
echo "  hdc install -r \"$OUTPUT\""
