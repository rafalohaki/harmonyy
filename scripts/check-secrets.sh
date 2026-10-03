#!/usr/bin/env bash
#
# Refuse to publish a secret.
#
# The submission repository is public, so this runs as part of the no-SDK gate.
# It deliberately looks for HIGH-CONFIDENCE patterns only: a scanner that cries
# wolf gets ignored, and an ignored scanner is worse than none.
#
# What it checks:
#   1. private key blocks
#   2. well-known provider key prefixes with realistic lengths
#   3. signing material committed to the repository
#   4. that the local-only directories are still ignored
#
# It does NOT flag documented placeholders such as `BRIDGE_API_KEY=sk-...`, the
# SDK's public development password, or the word "apiKey".
#
# Usage:
#   scripts/check-secrets.sh

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"

cd "$BRIDGE_REPO_ROOT"

findings=0

# ---------------------------------------------------------------------------
# 1. Private key material
# ---------------------------------------------------------------------------
if git grep -qE -- '-----BEGIN [A-Z ]*PRIVATE KEY-----' -- . 2>/dev/null; then
  echo "FOUND private key block in:"
  git grep -lE -- '-----BEGIN [A-Z ]*PRIVATE KEY-----' -- .
  findings=$((findings + 1))
fi

# ---------------------------------------------------------------------------
# 2. Provider key prefixes. The length thresholds are what separate a real key
#    from a documented placeholder like `sk-...`.
# ---------------------------------------------------------------------------
PATTERN='(sk-[A-Za-z0-9_-]{20,}|gsk_[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{30,})'
if git grep -qE -- "$PATTERN" -- . 2>/dev/null; then
  echo "FOUND provider API key in:"
  git grep -nE -- "$PATTERN" -- . | sed 's/\(.\{160\}\).*/\1.../'
  findings=$((findings + 1))
fi

# ---------------------------------------------------------------------------
# 3. Signing material
# ---------------------------------------------------------------------------
tracked_material="$(git ls-files | grep -E '\.(p12|pfx|jks|keystore|p7b)$' || true)"
if [ -n "$tracked_material" ]; then
  echo "FOUND signing material tracked in git:"
  echo "$tracked_material"
  findings=$((findings + 1))
fi

# ---------------------------------------------------------------------------
# 4. Local-only directories must stay ignored
# ---------------------------------------------------------------------------
for dir in .tools .home .downloads _ref; do
  if git ls-files --error-unmatch "$dir" >/dev/null 2>&1; then
    echo "FOUND tracked files under $dir (must be ignored):"
    git ls-files "$dir" | head -5
    findings=$((findings + 1))
  fi
done

echo
if [ "$findings" -gt 0 ]; then
  echo "SECRET CHECK FAILED ($findings finding group(s)). Do not publish."
  exit 1
fi

echo "secret check: clean (no private keys, provider keys, signing material or tracked local dirs)"
