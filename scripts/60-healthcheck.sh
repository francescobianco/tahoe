#!/usr/bin/env bash
set -e

: "${SFTP_HOST:?SFTP_HOST was missing}"
: "${SFTP_PORT:?SFTP_PORT was missing}"
: "${SFTP_USER:?SFTP_USER was missing}"
: "${SFTP_PASSWORD:?SFTP_PASSWORD was missing}"
: "${HEALTHCHECK_MAIL_TO:?HEALTHCHECK_MAIL_TO was missing}"

command -v sshpass &>/dev/null || sudo apt-get install -y -qq sshpass

fail() {
    echo "$1" | mail -s "Tahoe FAILED" "$HEALTHCHECK_MAIL_TO"
    exit 1
}

sftp_run() {
    sshpass -p "$SFTP_PASSWORD" sftp \
        -P "$SFTP_PORT" \
        -o StrictHostKeyChecking=no \
        -o BatchMode=no \
        -b - \
        "$SFTP_USER@$SFTP_HOST"
}

TMP=$(mktemp -d)
LOCAL="$TMP/test.bin"
DOWN="$TMP/down.bin"

dd if=/dev/urandom of="$LOCAL" bs=1M count=32 status=none

sftp_run <<EOF || fail "upload"
-mkdir healthcheck
put $LOCAL healthcheck/test.bin
EOF

sftp_run <<EOF || fail "download"
get healthcheck/test.bin $DOWN
EOF

H1=$(sha256sum "$LOCAL" | cut -d' ' -f1)
H2=$(sha256sum "$DOWN"  | cut -d' ' -f1)
[ "$H1" = "$H2" ] || fail "hash mismatch"

rm -rf "$TMP"
echo "OK"
