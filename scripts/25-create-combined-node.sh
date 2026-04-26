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

docker compose up -d node

echo "Nodo combinato (storage + SFTP gateway) avviato."
