#!/usr/bin/env bash
set -e

: "${TAHOE_BASE:?TAHOE_BASE was missing}"
: "${INTRODUCER_HOSTNAME:?INTRODUCER_HOSTNAME was missing}"

source "$TAHOE_BASE/venv/bin/activate"

NODE="$TAHOE_BASE/introducer"

tahoe create-introducer --hostname="$INTRODUCER_HOSTNAME" "$NODE"

echo "Introducer creato:"
cat "$NODE/private/introducer.furl"
