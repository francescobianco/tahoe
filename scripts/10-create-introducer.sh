#!/usr/bin/env bash
set -e

: "${INTRODUCER_HOSTNAME:?INTRODUCER_HOSTNAME was missing}"

FURL_FILE="${TAHOE_BASE:-/opt/tahoe}/data/introducer/private/introducer.furl"

if [ -f "$FURL_FILE" ]; then
    echo "Introducer gia avviato. FURL:"
    cat "$FURL_FILE"
    exit 0
fi

docker compose up -d introducer

echo "Attendo generazione FURL..."
for i in $(seq 1 30); do
    if [ -f "$FURL_FILE" ]; then break; fi
    sleep 1
done

if [ ! -f "$FURL_FILE" ]; then
    echo "Errore: FURL non generato dopo 30 secondi."
    docker compose logs introducer
    exit 1
fi

echo ""
echo "FURL generato. Copia questo valore nel tuo .env come INTRODUCER_FURL:"
echo ""
cat "$FURL_FILE"
