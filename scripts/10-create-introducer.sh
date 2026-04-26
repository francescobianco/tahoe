#!/usr/bin/env bash
set -e

: "${TAHOE_BASE:?TAHOE_BASE was missing}"
: "${INTRODUCER_HOSTNAME:?INTRODUCER_HOSTNAME was missing}"

source "$TAHOE_BASE/venv/bin/activate"

NODE="$TAHOE_BASE/introducer"
FURL="$NODE/private/introducer.furl"

if [ ! -d "$NODE" ]; then
    tahoe create-introducer --hostname="$INTRODUCER_HOSTNAME" "$NODE"
fi

if [ -f "$FURL" ]; then
    echo "Introducer gia avviato. FURL:"
    cat "$FURL"
    exit 0
fi

echo "Avvio introducer per generare il FURL..."
tahoe run "$NODE" &
TAHOE_PID=$!

for i in $(seq 1 30); do
    if [ -f "$FURL" ]; then
        break
    fi
    sleep 1
done

if [ ! -f "$FURL" ]; then
    kill "$TAHOE_PID" 2>/dev/null || true
    echo "Errore: FURL non generato dopo 30 secondi."
    exit 1
fi

echo ""
echo "FURL generato. Copia questo valore nel tuo .env come INTRODUCER_FURL:"
echo ""
cat "$FURL"
echo ""
echo "L'introducer e in esecuzione (PID $TAHOE_PID)."
echo "Usare 50-run-node.sh introducer per gestirlo stabilmente."
