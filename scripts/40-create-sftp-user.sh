#!/usr/bin/env bash
set -e

: "${TAHOE_BASE:?TAHOE_BASE non impostata}"
: "${SFTP_USER:?SFTP_USER non impostata}"
: "${SFTP_PASSWORD:?SFTP_PASSWORD non impostata}"

NODE="$TAHOE_BASE/gateway"
ACCOUNTS="$NODE/private/accounts"

echo "$SFTP_USER:$SFTP_PASSWORD:root" > "$ACCOUNTS"

echo "Utente SFTP creato"
