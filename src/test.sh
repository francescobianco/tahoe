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
  : "${SFTP_PRIVATE_KEY:?SFTP_PRIVATE_KEY was missing}"

  tahoe_require_command sftp || return 1
  tahoe_require_command sha256sum || return 1
  tahoe_require_command dd || return 1
  tahoe_require_command mktemp || return 1
  tahoe_require_command timeout || return 1

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
  local attempt_ok
  attempt_ok=0

  dd if=/dev/urandom of="$local_file" bs=1M count="$size_mb" status=none

  echo "Uploading ${size_mb}MiB to ${SFTP_USER}@${gateway_host}:${SFTP_PORT}/${remote_file}"
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
      "$SFTP_USER@$gateway_host" <<EOF
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

    echo "tahoe: gateway test attempt $attempt failed, retrying..." >&2
    sleep 2
  done

  if [ "$attempt_ok" -ne 1 ]; then
    echo "tahoe: gateway upload test failed: SFTP never became stable" >&2
    rm -rf "$tmp_dir"
    return 1
  fi

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

tahoe_upload_file() {
  local env_file
  env_file="$1"
  local local_file
  local_file="$2"
  local remote_dir
  remote_dir="$3"

  tahoe_load_env_file "$env_file" || return 1

  : "${SFTP_HOST:?SFTP_HOST was missing}"
  : "${SFTP_PORT:?SFTP_PORT was missing}"
  : "${SFTP_USER:?SFTP_USER was missing}"
  : "${SFTP_PRIVATE_KEY:?SFTP_PRIVATE_KEY was missing}"

  tahoe_require_command sftp || return 1
  tahoe_require_command timeout || return 1

  if [ ! -f "$local_file" ]; then
    echo "tahoe: local file not found: $local_file" >&2
    return 1
  fi

  local remote_target
  if [ "$remote_dir" = "/" ]; then
    remote_target="/$(basename "$local_file")"
  else
    remote_target="${remote_dir%/}/$(basename "$local_file")"
  fi

  if timeout 60 sftp \
    -P "$SFTP_PORT" \
    -i "$SFTP_PRIVATE_KEY" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o GlobalKnownHostsFile=/dev/null \
    -o BatchMode=no \
    -b - \
    "${SFTP_USER}@${SFTP_HOST}" <<EOF
-mkdir $remote_dir
put $local_file $remote_target
EOF
  then
    :
  else
    local sftp_status=$?
    if [ "$sftp_status" -ne 124 ]; then
      echo "tahoe: upload failed via ${SFTP_USER}@${SFTP_HOST}:${SFTP_PORT}" >&2
      return "$sftp_status"
    fi
  fi

  echo "Upload OK: ${local_file} -> ${SFTP_USER}@${SFTP_HOST}:${SFTP_PORT}:${remote_target}"
}
