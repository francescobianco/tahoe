#!/bin/bash
set -e

# vfs avoids overlay2 whiteout limitations in nested Docker environments
echo "[host] Starting Docker daemon (storage-driver=vfs)..."
dockerd \
  --host=unix:///var/run/docker.sock \
  --storage-driver=vfs \
  >/var/log/dockerd.log 2>&1 &

timeout 30 bash -c 'until docker info >/dev/null 2>&1; do sleep 1; done' \
  || { echo "[host] Docker daemon failed to start"; cat /var/log/dockerd.log; exit 1; }

echo "[host] Docker daemon ready."

echo "[host] Starting SSH daemon..."
exec /usr/sbin/sshd -D -e
