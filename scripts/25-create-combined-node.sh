#!/usr/bin/env bash
set -e

: "${INTRODUCER_FURL:?INTRODUCER_FURL was missing}"
: "${SHARES_NEEDED:?SHARES_NEEDED was missing}"
: "${SHARES_TOTAL:?SHARES_TOTAL was missing}"
: "${SHARES_HAPPY:?SHARES_HAPPY was missing}"
: "${STORAGE_RESERVED_SPACE:?STORAGE_RESERVED_SPACE was missing}"
: "${SFTP_PORT:?SFTP_PORT was missing}"
: "${SFTP_USER:?SFTP_USER was missing}"
: "${SFTP_PASSWORD:?SFTP_PASSWORD was missing}"

IMAGE="yafb/tahoe"
CONTAINER="tahoe-node"
DATA_DIR="${TAHOE_BASE:-/opt/tahoe}/data/node"

mkdir -p "$DATA_DIR"

docker rm -f "$CONTAINER" 2>/dev/null || true
docker pull "$IMAGE"
docker run -d \
    --name "$CONTAINER" \
    --restart unless-stopped \
    -e INTRODUCER_FURL="$INTRODUCER_FURL" \
    -e SHARES_NEEDED="$SHARES_NEEDED" \
    -e SHARES_TOTAL="$SHARES_TOTAL" \
    -e SHARES_HAPPY="$SHARES_HAPPY" \
    -e STORAGE_RESERVED_SPACE="$STORAGE_RESERVED_SPACE" \
    -e SFTP_PORT="$SFTP_PORT" \
    -e SFTP_USER="$SFTP_USER" \
    -e SFTP_PASSWORD="$SFTP_PASSWORD" \
    -v "$DATA_DIR:/node" \
    -p "${SFTP_PORT}:${SFTP_PORT}" \
    "$IMAGE" node

echo "Nodo combinato (storage + SFTP gateway) avviato: $CONTAINER"
