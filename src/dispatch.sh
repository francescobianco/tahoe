tahoe_save_furl() {
  local host_name="$1"
  local config_file="$2"

  local tmp_script
  tmp_script=$(mktemp /tmp/tahoe.XXXXXX)
  tahoe_remote_get_furl > "$tmp_script"

  local furl
  furl=$(tahoe_run_host_capture "$host_name" "$config_file" "$tmp_script" 2>/dev/null | tr -d '\r\n ')
  rm -f "$tmp_script"

  if [ -z "$furl" ] || [ "${furl#pb://}" = "$furl" ]; then
    echo "tahoe: warning: could not read FURL from introducer" >&2
    return 0
  fi

  tahoe_config_set "$config_file" "INTRODUCER_FURL" "$furl"
  echo "tahoe: INTRODUCER_FURL saved to $config_file"
}

tahoe_with_remote_script() {
  local command_name
  command_name="$1"
  local host_name
  host_name="$2"
  local config_file
  config_file="$3"
  local tmp_script
  tmp_script=$(mktemp /tmp/tahoe.XXXXXX)

  case "$command_name" in
    introducer)      tahoe_remote_introducer > "$tmp_script" ;;
    node)            tahoe_remote_node > "$tmp_script" ;;
    gateway)         tahoe_remote_gateway > "$tmp_script" ;;
    introducer-logs) tahoe_remote_logs "introducer" > "$tmp_script" ;;
    node-logs)       tahoe_remote_logs "node" > "$tmp_script" ;;
    gateway-logs)    tahoe_remote_logs "gateway" > "$tmp_script" ;;
    *)
      echo "tahoe: unknown remote command: $command_name" >&2
      rm -f "$tmp_script"
      return 1
      ;;
  esac

  tahoe_run_host "$host_name" "$config_file" "$tmp_script"
  local exit_code=$?
  rm -f "$tmp_script"

  if [ "$exit_code" -eq 0 ] && [ "$command_name" = "introducer" ]; then
    tahoe_save_furl "$host_name" "$config_file"
  fi

  return "$exit_code"
}
