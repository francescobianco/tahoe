#!/usr/bin/env bash
set -e

: "${TAHOE_BASE:?TAHOE_BASE was missing}"
: "${INTRODUCER_FURL:?INTRODUCER_FURL was missing}"

TAHOE_NODE_NAME="tahoe-$(hostname -s)"

source "$TAHOE_BASE/venv/bin/activate"

NODE="$TAHOE_BASE/storage-$TAHOE_NODE_NAME"

tahoe create-node "$NODE"

cat >> "$NODE/tahoe.cfg" <<EOF

[client]
introducer.furl = $INTRODUCER_FURL

[storage]
enabled = true
reserved_space = 1G
EOF

echo "Storage node creato: $NODE"
