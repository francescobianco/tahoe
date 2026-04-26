#!/usr/bin/env bash
set -e

: "${TAHOE_BASE:?TAHOE_BASE was missing}"
: "${INTRODUCER_FURL:?INTRODUCER_FURL was missing}"

TAHOE_NODE_NAME="tahoe-$(hostname -s)"
: "${SHARES_NEEDED:?SHARES_NEEDED was missing}"
: "${SHARES_TOTAL:?SHARES_TOTAL was missing}"
: "${SHARES_HAPPY:?SHARES_HAPPY was missing}"
: "${STORAGE_RESERVED_SPACE:?STORAGE_RESERVED_SPACE was missing}"
: "${SFTP_PORT:?SFTP_PORT was missing}"
: "${SFTP_USER:?SFTP_USER was missing}"
: "${SFTP_PASSWORD:?SFTP_PASSWORD was missing}"

source "$TAHOE_BASE/venv/bin/activate"

NODE="$TAHOE_BASE/combined-$TAHOE_NODE_NAME"

if [ -d "$NODE" ]; then
    echo "Nodo combinato gia esistente: $NODE"
    exit 0
fi

tahoe create-node "$NODE"

cat >> "$NODE/tahoe.cfg" <<EOF

[client]
introducer.furl = $INTRODUCER_FURL
shares.needed = $SHARES_NEEDED
shares.total = $SHARES_TOTAL
shares.happy = $SHARES_HAPPY

[storage]
enabled = true
reserved_space = $STORAGE_RESERVED_SPACE

[sftpd]
enabled = true
port = tcp:$SFTP_PORT:interface=0.0.0.0
accounts.file = private/accounts
EOF

mkdir -p "$NODE/private"
echo "$SFTP_USER:$SFTP_PASSWORD:root" > "$NODE/private/accounts"

echo "Nodo combinato (storage + SFTP gateway) creato: $NODE"
