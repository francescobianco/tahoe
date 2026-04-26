#!/usr/bin/env bash
set -e

: "${TAHOE_BASE:?TAHOE_BASE non impostata}"
: "${TAHOE_NODE_NAME:?TAHOE_NODE_NAME non impostata}"
: "${INTRODUCER_FURL:?INTRODUCER_FURL non impostata}"

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
