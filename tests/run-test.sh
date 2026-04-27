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
FILEMANAGER_IP=172.20.0.15
ALL_IPS=($INTRODUCER_IP "${NODE_IPS[@]}" $GATEWAY_IP)
FILEMANAGER_ADMIN_USER=admin
FILEMANAGER_ADMIN_PASSWORD=tahoe-admin
FILEMANAGER_WEB_USER=tahoe
FILEMANAGER_WEB_PASSWORD=tahoe

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null -o ConnectTimeout=10 -o LogLevel=ERROR"

log()  { echo "[test] $*"; }
fail() { echo "[test] FAIL: $*" >&2; exit 1; }

ssh_exec() { local ip="$1"; shift; sshpass -p tahoe ssh $SSH_OPTS root@"$ip" "$@"; }
count_fragments() {
  local ip="$1"
  ssh_exec "$ip" 'find /opt/tahoe/data/node/storage/shares -type f 2>/dev/null | wc -l' | tr -d '[:space:]'
}

configure_filemanager() {
  local token_json
  token_json=$(curl --fail --silent --show-error --anyauth \
    -u "${FILEMANAGER_ADMIN_USER}:${FILEMANAGER_ADMIN_PASSWORD}" \
    "http://${FILEMANAGER_IP}:8080/api/v2/token")
  local token
  token=$(python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])' <<<"$token_json")

  local payload
  payload=$(python3 - "$SFTP_PRIVATE_KEY" <<'PY'
import json
import sys

private_key_path = sys.argv[1]
with open(private_key_path, "r", encoding="utf-8") as fh:
    private_key = fh.read()

payload = {
    "status": 1,
    "username": "tahoe",
    "password": "tahoe",
    "home_dir": "/",
    "permissions": {"/": ["*"]},
    "filesystem": {
        "provider": 5,
        "sftpconfig": {
            "endpoint": "172.20.0.14:8022",
            "username": "tahoe",
            "private_key": {
                "status": "Plain",
                "payload": private_key,
            },
        },
    },
}
print(json.dumps(payload))
PY
)

  local http_code
  http_code=$(curl --silent --show-error --output /tmp/tahoe-sftpgo-user.json --write-out '%{http_code}' \
    -X PUT \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "http://${FILEMANAGER_IP}:8080/api/v2/users/${FILEMANAGER_WEB_USER}?disconnect=1")

  if [ "$http_code" = "404" ]; then
    curl --fail --silent --show-error \
      -X POST \
      -H "Authorization: Bearer ${token}" \
      -H "Content-Type: application/json" \
      -d "$payload" \
      "http://${FILEMANAGER_IP}:8080/api/v2/users" >/dev/null
  elif [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ]; then
    cat /tmp/tahoe-sftpgo-user.json >&2 || true
    fail "unable to configure SFTPGo user, HTTP ${http_code}"
  fi

  rm -f /tmp/tahoe-sftpgo-user.json
}

run_local_sftp_test() {
  local size_mb
  size_mb="${TAHOE_TEST_SIZE_MB:-1}"
  local tmp_dir
  tmp_dir=$(mktemp -d)
  local local_file
  local_file="$tmp_dir/upload.bin"
  local downloaded_file
  downloaded_file="$tmp_dir/download.bin"
  local remote_dir
  remote_dir="tahoe-test"
  local remote_file
  remote_file="${remote_dir}/test-$(date +%s)-$$.bin"
  local attempt_ok
  attempt_ok=0

  dd if=/dev/urandom of="$local_file" bs=1M count="$size_mb" status=none

  echo "Uploading ${size_mb}MiB to ${SFTP_USER}@${GATEWAY_IP}:${SFTP_PORT}/${remote_file}"
  for attempt in $(seq 1 30); do
    local sftp_status
    sftp_status=0

    if timeout 20 sftp \
      -P "$SFTP_PORT" \
      -i "$SFTP_PRIVATE_KEY" \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o GlobalKnownHostsFile=/dev/null \
      -o BatchMode=no \
      -b - \
      "${SFTP_USER}@${GATEWAY_IP}" <<EOF
-mkdir $remote_dir
put $local_file $remote_file
get $remote_file $downloaded_file
EOF
    then
      sftp_status=0
    else
      sftp_status=$?
    fi

    if { [ "$sftp_status" -eq 0 ] || [ "$sftp_status" -eq 124 ]; } && [ -s "$downloaded_file" ]; then
      attempt_ok=1
      break
    fi

    echo "SFTP attempt $attempt failed, retrying..." >&2
    sleep 2
  done

  [ "$attempt_ok" -eq 1 ] || {
    echo "gateway upload test failed: SFTP never became stable" >&2
    rm -rf "$tmp_dir"
    return 1
  }

  local source_hash
  source_hash=$(sha256sum "$local_file" | cut -d' ' -f1)
  local downloaded_hash
  downloaded_hash=$(sha256sum "$downloaded_file" | cut -d' ' -f1)
  rm -rf "$tmp_dir"

  [ "$source_hash" = "$downloaded_hash" ] || {
    echo "gateway upload test failed: hash mismatch" >&2
    return 1
  }

  echo "Gateway upload test OK: $source_hash"
}

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

for cmd in docker sshpass sftp ssh-keygen sha256sum dd timeout curl python3; do
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
    -e 's|TAHOE_WEB_PORT=.*|TAHOE_WEB_PORT=3456|' \
    -e 's|TAHOE_WEB_URL=.*|TAHOE_WEB_URL="http://172.20.0.14:3456/"|' \
    -e 's|FILEMANAGER_URL=.*|FILEMANAGER_URL="http://172.20.0.15:8080/web/client/login"|' \
    "$CONFIG_FILE"
  log "Config ready: $CONFIG_FILE"
fi

# shellcheck disable=SC1090
. "$CONFIG_FILE"

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
  ssh_exec "$GATEWAY_IP" "printf '' | nc -w 2 localhost 8022 2>/dev/null | grep -q '^SSH-2.0-'" && break || true
  sleep 3
done
ssh_exec "$GATEWAY_IP" "printf '' | nc -w 2 localhost 8022 2>/dev/null | grep -q '^SSH-2.0-'" \
  || fail "gateway SFTP banner not ready after timeout"
log "  SFTP banner ready."

log "Waiting for Tahoe web UI on gateway..."
for i in $(seq 1 60); do
  curl -fsS "http://${GATEWAY_IP}:3456/" >/dev/null && break || true
  sleep 2
done
curl -fsS "http://${GATEWAY_IP}:3456/" >/dev/null \
  || fail "gateway Tahoe web UI not ready after timeout"
log "  Tahoe web UI ready: http://${GATEWAY_IP}:3456/"

log "Waiting for SFTPGo web client..."
for i in $(seq 1 60); do
  curl -fsS "http://${FILEMANAGER_IP}:8080/healthz" >/dev/null && break || true
  sleep 2
done
curl -fsS "http://${FILEMANAGER_IP}:8080/healthz" >/dev/null \
  || fail "SFTPGo health endpoint not ready after timeout"
configure_filemanager
curl -fsS "http://${FILEMANAGER_IP}:8080/web/client/login" >/dev/null \
  || fail "SFTPGo web client login page not reachable"
log "  File manager ready: http://${FILEMANAGER_IP}:8080/web/client/login"

# ── upload/download test via tahoe CLI ────────────────────────────────────────

log "Capturing fragment counts before upload..."
before_counts=()
for ip in "${NODE_IPS[@]}"; do
  before_counts+=("$(count_fragments "$ip")")
done

log "Running local SFTP upload/download test through ${GATEWAY_IP}:${SFTP_PORT}..."
run_local_sftp_test

log "Verifying fragment creation on storage nodes..."
nodes_with_new_fragments=0
total_new_fragments=0
after_counts=()
for i in 1 2 3; do
  ip="${NODE_IPS[$((i-1))]}"
  after_counts+=("$(count_fragments "$ip")")
  before_count="${before_counts[$((i-1))]}"
  after_count="${after_counts[$((i-1))]}"
  delta=$((after_count - before_count))
  if [ "$delta" -gt 0 ]; then
    nodes_with_new_fragments=$((nodes_with_new_fragments + 1))
    total_new_fragments=$((total_new_fragments + delta))
  fi
  log "  node$i fragments: before=$before_count after=$after_count delta=$delta"
done

[ "$total_new_fragments" -gt 0 ] \
  || fail "upload test completed but no new storage fragments were created"
[ "$nodes_with_new_fragments" -ge "${SHARES_NEEDED}" ] \
  || fail "expected new fragments on at least ${SHARES_NEEDED} nodes, got ${nodes_with_new_fragments}"

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
log "Tahoe web UI: http://${GATEWAY_IP}:3456/"
log "File manager: http://${FILEMANAGER_IP}:8080/web/client/login"
log "File manager credentials: ${FILEMANAGER_WEB_USER}/${FILEMANAGER_WEB_PASSWORD}"
log "============================================"
log "All tests passed."
log "============================================"
log "Cluster is up. To tear down: ./run-test.sh --down"
