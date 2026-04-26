#!/usr/bin/env bash
set -e

: "${TAHOE_BASE:?TAHOE_BASE non impostata}"
: "${HEALTHCHECK_MAIL_TO:?HEALTHCHECK_MAIL_TO non impostata}"

source "$TAHOE_BASE/venv/bin/activate"

TMP=$(mktemp -d)
LOCAL="$TMP/test.bin"
DOWN="$TMP/down.bin"
REMOTE="tahoe:healthcheck/test.bin"

fail() {
  echo "$1" | mail -s "Tahoe FAILED" "$HEALTHCHECK_MAIL_TO"
  exit 1
}

dd if=/dev/urandom of="$LOCAL" bs=1M count=32 status=none

tahoe mkdir tahoe:healthcheck || true
tahoe put "$LOCAL" "$REMOTE" || fail "upload"
tahoe check "$REMOTE" || fail "check"
tahoe get "$REMOTE" "$DOWN" || fail "download"

H1=$(sha256sum "$LOCAL" | cut -d' ' -f1)
H2=$(sha256sum "$DOWN" | cut -d' ' -f1)

[ "$H1" = "$H2" ] || fail "hash mismatch"

rm -rf "$TMP"
echo "OK"
