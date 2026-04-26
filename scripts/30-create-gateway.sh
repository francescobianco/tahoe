#!/usr/bin/env bash
set -e

source .env
source "$TAHOE_BASE/venv/bin/activate"

NODE="$TAHOE_BASE/gateway"

tahoe create-node "$NODE"

cat >> "$NODE/tahoe.cfg" <<EOF

[client]
introducer.furl = $INTRODUCER_FURL
shares.needed = $SHARES_NEEDED
shares.total = $SHARES_TOTAL
shares.happy = $SHARES_HAPPY

[storage]
enabled = false

[sftpd]
enabled = true
port = tcp:$SFTP_PORT:interface=0.0.0.0
accounts.file = private/accounts
EOF

mkdir -p "$NODE/private"
