#!/usr/bin/env bash
set -e

: "${HEALTHCHECK_MAIL_TO:?HEALTHCHECK_MAIL_TO was missing}"

fail() {
    echo "$1" | mail -s "Tahoe FAILED" "$HEALTHCHECK_MAIL_TO"
    exit 1
}

TMP=$(mktemp -d)
LOCAL="$TMP/test.bin"
DOWN="$TMP/down.bin"
REMOTE="tahoe:healthcheck/test.bin"

dd if=/dev/urandom of="$LOCAL" bs=1M count=32 status=none

docker compose exec node tahoe mkdir tahoe:healthcheck 2>/dev/null || true
docker compose exec -T node tahoe put - "$REMOTE" < "$LOCAL"   || fail "upload"
docker compose exec    node tahoe check "$REMOTE"               || fail "check"
docker compose exec -T node tahoe get "$REMOTE" -   > "$DOWN"   || fail "download"

H1=$(sha256sum "$LOCAL" | cut -d' ' -f1)
H2=$(sha256sum "$DOWN"  | cut -d' ' -f1)
[ "$H1" = "$H2" ] || fail "hash mismatch"

rm -rf "$TMP"
echo "OK"
