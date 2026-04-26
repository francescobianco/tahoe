#!/usr/bin/env bash
set -e

: "${TAHOE_BASE:?TAHOE_BASE was missing}"
: "${SFTP_USER:?SFTP_USER was missing}"
: "${SFTP_PASSWORD:?SFTP_PASSWORD was missing}"

NODE="$TAHOE_BASE/gateway"
ACCOUNTS="$NODE/private/accounts"

echo "$SFTP_USER:$SFTP_PASSWORD:root" > "$ACCOUNTS"

echo "Utente SFTP creato"
