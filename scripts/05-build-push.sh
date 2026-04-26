#!/usr/bin/env bash
set -e

IMAGE="yafb/tahoe"
TAG="${1:-latest}"

docker build -t "${IMAGE}:${TAG}" .
docker push "${IMAGE}:${TAG}"

if [ "$TAG" != "latest" ]; then
    docker tag "${IMAGE}:${TAG}" "${IMAGE}:latest"
    docker push "${IMAGE}:latest"
fi

echo "Pushed ${IMAGE}:${TAG}"
