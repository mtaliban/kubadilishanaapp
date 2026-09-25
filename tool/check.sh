#!/usr/bin/env bash
# ============================================================================
# tool/check.sh — Ulinzi wa CI (endesha KABLA ya kila push!)
# ----------------------------------------------------------------------------
# Matumizi:
#   ./tool/check.sh            # analyze + test zote
#   ./tool/check.sh --analyze  # analyze tu (haraka, ~sekunde 5)
#
# Hii ni ile ile ambayo GitHub Actions inafanya kwenye "Build & Release APK":
#   1. flutter analyze --no-fatal-infos   (errors zinazuia, warnings hazii)
#   2. flutter test --no-pub              (test zote lazima zipite)
# Ukishindwa hapa, CI itashindwa huko — rekebisha kabla ya push.
# ============================================================================
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

# Tumia Flutter iliyopo (au FLUTTER_BIN env)
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
if ! command -v "$FLUTTER_BIN" >/dev/null 2>&1; then
  for c in /tmp/flutter/bin/flutter ~/flutter/bin/flutter; do
    [ -x "$c" ] && FLUTTER_BIN="$c" && break
  done
fi

echo "==> Flutter: $($FLUTTER_BIN --version 2>/dev/null | head -1)"
FAIL=0

# ── 1. ANALYZE (errors pekee ndizo zinakatiza CI) ────────────────────────────
echo "==> [1/2] flutter analyze ..."
if ! "$FLUTTER_BIN" analyze 2>&1 | grep -E "error •" >/tmp/_analyze_err.txt; then
  : # hakuna error
fi
if [ -s /tmp/_analyze_err.txt ]; then
  echo "❌ ANALYZE — kuna ERRORS:"
  cat /tmp/_analyze_err.txt
  FAIL=1
else
  echo "✅ analyze: hakuna error"
fi

# ── 2. TESTS zote (kama CI) ──────────────────────────────────────────────────
if [ "${1:-}" != "--analyze" ]; then
  echo "==> [2/2] flutter test --no-pub ..."
  if "$FLUTTER_BIN" test --no-pub >/tmp/_test_out.txt 2>&1; then
    echo "✅ test: $(grep -oE '\+[0-9]+( -[0-9]+)?: All tests passed' /tmp/_test_out.txt | tail -1)"
  else
    echo "❌ TEST — zilizoshindwa:"
    grep -E "^\s+-\s|Some tests failed|\[E\]" /tmp/_test_out.txt | head -20
    echo "(ujumbe kamili: /tmp/_test_out.txt)"
    FAIL=1
  fi
fi

echo "────────────────────────────────────────"
if [ "$FAIL" -eq 0 ]; then
  echo "✅ VYOTE SAWA — unaweza push"
  exit 0
else
  echo "❌ USIPUSH — rekebisha makosa hapo juu kwanza"
  exit 1
fi
