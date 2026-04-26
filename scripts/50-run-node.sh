#!/usr/bin/env bash
set -e

TYPE=$1

case "$TYPE" in
    introducer) CONTAINER="tahoe-introducer" ;;
    node)       CONTAINER="tahoe-node" ;;
    *)
        echo "Uso: $0 [introducer|node]"
        exit 1
        ;;
esac

if docker inspect "$CONTAINER" &>/dev/null 2>&1; then
    docker start "$CONTAINER"
else
    echo "Container $CONTAINER non esiste. Esegui prima lo script di creazione."
    exit 1
fi
