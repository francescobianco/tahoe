tahoe_with_remote_script() {
  local command_name
  command_name="$1"
  local host_name
  host_name="$2"
  local env_file
  env_file="$3"
  local tmp_script
  tmp_script=$(mktemp /tmp/tahoe.XXXXXX)

  case "$command_name" in
    introducer) tahoe_remote_introducer > "$tmp_script" ;;
    node) tahoe_remote_node > "$tmp_script" ;;
    gateway) tahoe_remote_gateway > "$tmp_script" ;;
    introducer-logs) tahoe_remote_logs "introducer" > "$tmp_script" ;;
    node-logs) tahoe_remote_logs "node" > "$tmp_script" ;;
    gateway-logs) tahoe_remote_logs "gateway" > "$tmp_script" ;;
    *) echo "tahoe: unknown remote command: $command_name" >&2; rm -f "$tmp_script"; return 1 ;;
  esac

  tahoe_run_host "$host_name" "$env_file" "$tmp_script"
  local exit_code
  exit_code=$?
  rm -f "$tmp_script"
  return "$exit_code"
}
