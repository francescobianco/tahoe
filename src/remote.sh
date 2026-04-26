tahoe_remote_introducer() {
  cat <<'EOF'
set -e

: "${INTRODUCER_HOSTNAME:?INTRODUCER_HOSTNAME was missing}"

IMAGE="${TAHOE_IMAGE:-yafb/tahoe}"
CONTAINER="${TAHOE_INTRODUCER_CONTAINER:-tahoe-introducer}"
INTRODUCER_PORT="${INTRODUCER_PORT:-3458}"
DATA_DIR="${TAHOE_BASE:-/opt/tahoe}/data/introducer"
FURL_FILE="$DATA_DIR/private/introducer.furl"

mkdir -p "$DATA_DIR"

if [ -f "$FURL_FILE" ]; then
  echo "Introducer already exists on $tahoe_name. FURL:"
  cat "$FURL_FILE"
  exit 0
fi

docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
docker pull "$IMAGE"
docker run -d \
  --name "$CONTAINER" \
  --restart unless-stopped \
  -e INTRODUCER_HOSTNAME="$INTRODUCER_HOSTNAME" \
  -e INTRODUCER_PORT="$INTRODUCER_PORT" \
  -v "$DATA_DIR:/node" \
  -p "${INTRODUCER_PORT}:${INTRODUCER_PORT}" \
  "$IMAGE" introducer

echo "Waiting for introducer FURL..."
for i in $(seq 1 30); do
  [ -f "$FURL_FILE" ] && break
  sleep 1
done

if [ ! -f "$FURL_FILE" ]; then
  echo "tahoe: FURL not generated after 30 seconds" >&2
  docker logs "$CONTAINER" >&2
  exit 1
fi

echo "FURL generated. Put this value in your local env file as INTRODUCER_FURL:"
cat "$FURL_FILE"
EOF
}

tahoe_remote_node() {
  cat <<'EOF'
set -e

: "${INTRODUCER_FURL:?INTRODUCER_FURL was missing}"
: "${SHARES_NEEDED:?SHARES_NEEDED was missing}"
: "${SHARES_TOTAL:?SHARES_TOTAL was missing}"
: "${SHARES_HAPPY:?SHARES_HAPPY was missing}"
: "${STORAGE_RESERVED_SPACE:?STORAGE_RESERVED_SPACE was missing}"

IMAGE="${TAHOE_IMAGE:-yafb/tahoe}"
CONTAINER="${TAHOE_NODE_CONTAINER:-tahoe-node}"
NODE_PORT="${NODE_PORT:-3457}"
DATA_DIR="${TAHOE_BASE:-/opt/tahoe}/data/node"
TAHOE_NODE_HOSTNAME="${TAHOE_NODE_HOSTNAME:-$tahoe_host}"

mkdir -p "$DATA_DIR"

docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
docker pull "$IMAGE"
docker run -d \
  --name "$CONTAINER" \
  --restart unless-stopped \
  -e TAHOE_NODE_HOSTNAME="$TAHOE_NODE_HOSTNAME" \
  -e INTRODUCER_FURL="$INTRODUCER_FURL" \
  -e NODE_PORT="$NODE_PORT" \
  -e SHARES_NEEDED="$SHARES_NEEDED" \
  -e SHARES_TOTAL="$SHARES_TOTAL" \
  -e SHARES_HAPPY="$SHARES_HAPPY" \
  -e STORAGE_RESERVED_SPACE="$STORAGE_RESERVED_SPACE" \
  -v "$DATA_DIR:/node" \
  -p "${NODE_PORT}:${NODE_PORT}" \
  "$IMAGE" node

echo "Storage node started on $tahoe_name: $CONTAINER"
EOF
}

tahoe_remote_gateway() {
  cat <<'EOF'
set -e

: "${INTRODUCER_FURL:?INTRODUCER_FURL was missing}"
: "${SHARES_NEEDED:?SHARES_NEEDED was missing}"
: "${SHARES_TOTAL:?SHARES_TOTAL was missing}"
: "${SHARES_HAPPY:?SHARES_HAPPY was missing}"
: "${SFTP_PORT:?SFTP_PORT was missing}"
: "${SFTP_USER:?SFTP_USER was missing}"
: "${SFTP_PUBLIC_KEY:?SFTP_PUBLIC_KEY was missing; set it or set SFTP_PRIVATE_KEY locally}"

IMAGE="${TAHOE_IMAGE:-yafb/tahoe}"
CONTAINER="${TAHOE_GATEWAY_CONTAINER:-tahoe-gateway}"
GATEWAY_PORT="${GATEWAY_PORT:-3459}"
DATA_DIR="${TAHOE_BASE:-/opt/tahoe}/data/gateway"
TAHOE_NODE_HOSTNAME="${TAHOE_NODE_HOSTNAME:-$tahoe_host}"

mkdir -p "$DATA_DIR"

docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
docker pull "$IMAGE"
docker run -d \
  --name "$CONTAINER" \
  --restart unless-stopped \
  -e TAHOE_NODE_HOSTNAME="$TAHOE_NODE_HOSTNAME" \
  -e INTRODUCER_FURL="$INTRODUCER_FURL" \
  -e NODE_PORT="$GATEWAY_PORT" \
  -e SHARES_NEEDED="$SHARES_NEEDED" \
  -e SHARES_TOTAL="$SHARES_TOTAL" \
  -e SHARES_HAPPY="$SHARES_HAPPY" \
  -e SFTP_PORT="$SFTP_PORT" \
  -e SFTP_USER="$SFTP_USER" \
  -e SFTP_PUBLIC_KEY="$SFTP_PUBLIC_KEY" \
  -e SFTP_ROOTCAP="${SFTP_ROOTCAP:-auto}" \
  -v "$DATA_DIR:/node" \
  -p "${GATEWAY_PORT}:${GATEWAY_PORT}" \
  -p "${SFTP_PORT}:${SFTP_PORT}" \
  "$IMAGE" gateway

echo "Gateway started on $tahoe_name: $CONTAINER"
EOF
}

tahoe_remote_logs() {
  local role
  role="$1"

  cat <<'EOF'
set -e
EOF

  case "$role" in
    introducer)
      cat <<'EOF'
CONTAINER="${TAHOE_INTRODUCER_CONTAINER:-tahoe-introducer}"
EOF
      ;;
    node)
      cat <<'EOF'
CONTAINER="${TAHOE_NODE_CONTAINER:-tahoe-node}"
EOF
      ;;
    gateway)
      cat <<'EOF'
CONTAINER="${TAHOE_GATEWAY_CONTAINER:-tahoe-gateway}"
EOF
      ;;
  esac

  cat <<'EOF'
if ! docker inspect "$CONTAINER" >/dev/null 2>&1; then
  echo "tahoe: container not found on $tahoe_name: $CONTAINER" >&2
  exit 1
fi

docker logs "$CONTAINER"
EOF
}
