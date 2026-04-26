#!/usr/bin/env bash
set -e

source .env

NODE="$TAHOE_BASE/gateway"
ACCOUNTS="$NODE/private/accounts"

echo "$SFTP_USER:$SFTP_PASSWORD:root" > "$ACCOUNTS"

echo "Utente SFTP creato"
