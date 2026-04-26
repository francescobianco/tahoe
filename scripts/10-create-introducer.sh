#!/usr/bin/env bash
set -e

: "${TAHOE_BASE:?TAHOE_BASE non impostata}"

source "$TAHOE_BASE/venv/bin/activate"

NODE="$TAHOE_BASE/introducer"

tahoe create-introducer "$NODE"

echo "Introducer creato:"
cat "$NODE/private/introducer.furl"
