#!/usr/bin/env bash
# Integration test: builds a Tahoe-LAFS cluster using only the tahoe CLI.
#
# Usage:
#   ./run-test.sh          run the full test, leave cluster up
#   ./run-test.sh --clean  destroy everything first, then run
#   ./run-test.sh --down   tear down the cluster
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$TESTS_DIR")"
TAHOE="$REPO_DIR/bin/tahoe"
HOSTS_FILE="$TESTS_DIR/.hosts"
CONFIG_FILE="$TESTS_DIR/.tahoe"
COMPOSE="docker compose -f $TESTS_DIR/docker-compose.yml"
TAHOE_CMD="$TAHOE --config $CONFIG_FILE --hosts $HOSTS_FILE"

INTRODUCER_IP=172.20.0.10
NODE_IPS=(172.20.0.11 172.20.0.12 172.20.0.13)
GATEWAY_IP=172.20.0.14
ALL_IPS=($INTRODUCER_IP "${NODE_IPS[@]}" $GATEWAY_IP)

SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10 -o LogLevel=ERROR"

log()  { echo "[test] $*"; }
fail() { echo "[test] FAIL: $*" >&2; exit 1; }

ssh_exec() { local ip="$1"; shift; sshpass -p tahoe ssh $SSH_OPTS root@"$ip" "$@"; }

# ── arguments ─────────────────────────────────────────────────────────────────

case "${1:-}" in
  --down)
    log "Tearing down cluster..."
    $COMPOSE down -v
    exit 0
    ;;
  --clean)
    log "Cleaning up previous run..."
    $COMPOSE down -v 2>/dev/null || true
    rm -f "$CONFIG_FILE" "$TESTS_DIR/.tahoe.pem" "$TESTS_DIR/.tahoe.key"
    ;;
  "") ;;
  *)
    echo "Usage: $0 [--clean|--down]" >&2; exit 1 ;;
esac

# ── prerequisites ─────────────────────────────────────────────────────────────

for cmd in docker sshpass sftp ssh-keygen sha256sum dd; do
  command -v "$cmd" >/dev/null 2>&1 || fail "required command not found: $cmd"
done
[ -x "$TAHOE" ] || fail "tahoe binary not found: $TAHOE"

# ── init config (once) ────────────────────────────────────────────────────────

if [ ! -f "$CONFIG_FILE" ]; then
  log "Running tahoe init..."
  (cd "$TESTS_DIR" && "$TAHOE" init)

  # Patch template values for the test cluster
  sed -i \
    -e 's|INTRODUCER_HOSTNAME=.*|INTRODUCER_HOSTNAME="172.20.0.10"|' \
    -e 's|SHARES_NEEDED=.*|SHARES_NEEDED=2|' \
    -e 's|SHARES_TOTAL=.*|SHARES_TOTAL=3|' \
    -e 's|SHARES_HAPPY=.*|SHARES_HAPPY=2|' \
    -e 's|STORAGE_RESERVED_SPACE=.*|STORAGE_RESERVED_SPACE=1G|' \
    -e 's|SFTP_HOST=.*|SFTP_HOST="172.20.0.14"|' \
    -e 's|SFTP_USER=.*|SFTP_USER="tahoe"|' \
    -e "s|SFTP_PRIVATE_KEY=.*|SFTP_PRIVATE_KEY=\"$TESTS_DIR/.tahoe.pem\"|" \
    "$CONFIG_FILE"
  log "Config ready: $CONFIG_FILE"
fi

# ── start DinD hosts ──────────────────────────────────────────────────────────

log "Building and starting DinD hosts..."
$COMPOSE up -d --build

# ── wait for Docker daemon on every host ─────────────────────────────────────

log "Waiting for all hosts..."
for ip in "${ALL_IPS[@]}"; do
  for i in $(seq 1 60); do
    ssh_exec "$ip" 'docker info >/dev/null 2>&1' && break || true
    sleep 3
  done
  ssh_exec "$ip" 'docker info >/dev/null 2>&1' || fail "$ip: Docker not ready after timeout"
  log "  $ip OK"
done

# ── load yafb/tahoe into DinD hosts ──────────────────────────────────────────
# Build locally and pipe in so the test runs without internet access.

log "Building yafb/tahoe..."
docker build -q -t yafb/tahoe "$REPO_DIR/docker/"

log "Loading image into DinD hosts..."
IMAGE_TAR=$(mktemp)
docker save yafb/tahoe > "$IMAGE_TAR"
for ip in "${ALL_IPS[@]}"; do
  sshpass -p tahoe ssh $SSH_OPTS root@"$ip" 'docker load' < "$IMAGE_TAR" &
done
wait
rm -f "$IMAGE_TAR"
log "  image ready on all hosts."

# ── deploy cluster via tahoe CLI ──────────────────────────────────────────────

log "Deploying introducer..."
$TAHOE_CMD introducer introducer-host
# INTRODUCER_FURL is now automatically saved to $CONFIG_FILE by the CLI

log "Deploying storage nodes..."
$TAHOE_CMD node node1-host
$TAHOE_CMD node node2-host
$TAHOE_CMD node node3-host

log "Deploying gateway..."
$TAHOE_CMD gateway gateway-host

# ── wait for SFTP (gateway builds rootcap on first boot, ~60s) ───────────────

log "Waiting for SFTP on gateway..."
for i in $(seq 1 90); do
  ssh_exec "$GATEWAY_IP" 'nc -z localhost 8022 2>/dev/null' && break || true
  sleep 3
done
ssh_exec "$GATEWAY_IP" 'nc -z localhost 8022 2>/dev/null' \
  || fail "gateway SFTP port 8022 not open after timeout"
log "  SFTP ready."

# ── upload/download test via tahoe CLI ────────────────────────────────────────

log "Running SFTP upload/download test..."
$TAHOE_CMD gateway gateway-host --test

# ── show fragments on storage nodes ──────────────────────────────────────────

log "============================================"
log "Storage fragments on each node:"
for i in 1 2 3; do
  ip="${NODE_IPS[$((i-1))]}"
  log "--- node$i ($ip) ---"
  ssh_exec "$ip" \
    'find /opt/tahoe/data/node/storage/shares -type f 2>/dev/null | head -20 || echo "(no shares yet)"'
done

log "============================================"
log "All tests passed."
log "============================================"
log "Cluster is up. To tear down: ./run-test.sh --down"
