#!/usr/bin/env bash
set -e

: "${TAHOE_BASE:?TAHOE_BASE was missing}"
: "${TAHOE_NODE_NAME:?TAHOE_NODE_NAME was missing}"

source "$TAHOE_BASE/venv/bin/activate"

TYPE=$1

if [ "$TYPE" = "storage" ]; then
    NODE="$TAHOE_BASE/storage-$TAHOE_NODE_NAME"
elif [ "$TYPE" = "gateway" ]; then
    NODE="$TAHOE_BASE/gateway"
elif [ "$TYPE" = "introducer" ]; then
    NODE="$TAHOE_BASE/introducer"
else
    echo "Uso: $0 [storage|gateway|introducer]"
    exit 1
fi

tahoe run "$NODE"
