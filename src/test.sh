tahoe_gateway_test() {
  local host_name
  host_name="$1"
  local env_file
  env_file="$2"

  tahoe_load_env_file "$env_file" || return 1

  local host_line
  host_line=$(tahoe_hosts_find "$host_name") || return 1

  local gateway_host
  gateway_host="${SFTP_HOST:-}"
  if [ -z "$gateway_host" ]; then
    gateway_host=$(tahoe_hosts_get_field "$host_line" "host" || true)
  fi
  if [ "$gateway_host" = "0.0.0.0" ] || [ "$host_name" = "local" ]; then
    gateway_host="127.0.0.1"
  fi

  : "${SFTP_PORT:?SFTP_PORT was missing}"
  : "${SFTP_USER:?SFTP_USER was missing}"
  : "${SFTP_PASSWORD:?SFTP_PASSWORD was missing}"

  tahoe_require_command sshpass || return 1
  tahoe_require_command sftp || return 1
  tahoe_require_command sha256sum || return 1
  tahoe_require_command dd || return 1
  tahoe_require_command mktemp || return 1

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
  local size_mb
  size_mb="${TAHOE_TEST_SIZE_MB:-1}"

  dd if=/dev/urandom of="$local_file" bs=1M count="$size_mb" status=none

  echo "Uploading ${size_mb}MiB to ${SFTP_USER}@${gateway_host}:${SFTP_PORT}/${remote_file}"
  sshpass -p "$SFTP_PASSWORD" sftp \
    -P "$SFTP_PORT" \
    -o StrictHostKeyChecking=no \
    -o BatchMode=no \
    -b - \
    "$SFTP_USER@$gateway_host" <<EOF
-mkdir $remote_dir
put $local_file $remote_file
get $remote_file $downloaded_file
rm $remote_file
EOF

  local source_hash
  source_hash=$(sha256sum "$local_file" | cut -d' ' -f1)
  local downloaded_hash
  downloaded_hash=$(sha256sum "$downloaded_file" | cut -d' ' -f1)

  rm -rf "$tmp_dir"

  if [ "$source_hash" != "$downloaded_hash" ]; then
    echo "tahoe: gateway upload test failed: hash mismatch" >&2
    return 1
  fi

  echo "Gateway upload test OK: $source_hash"
}
