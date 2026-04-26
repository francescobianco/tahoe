#!/usr/bin/env bash
set -e

TYPE=$1

case "$TYPE" in
    introducer|node)
        docker compose up -d "$TYPE"
        ;;
    all)
        docker compose up -d
        ;;
    *)
        echo "Uso: $0 [introducer|node|all]"
        exit 1
        ;;
esac
