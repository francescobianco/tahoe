tahoe_require_command() {
  local command_name
  command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "tahoe: required command not found: $command_name" >&2
    return 1
  fi
}

# tty_mode: "tty" (interactive, default) | "notty" (capture-safe, no pseudo-tty)
tahoe_runner_exec() {
  local host_line
  host_line="$1"
  local script_file
  script_file="$2"
  local env_file
  env_file="$3"
  local tty_mode
  tty_mode="${4:-tty}"

  local host
  host=$(tahoe_hosts_get_field "$host_line" "host" || true)
  local user
  user=$(tahoe_hosts_get_field "$host_line" "user" || true)
  local password
  password=$(tahoe_hosts_get_field "$host_line" "password" || true)
  local name
  name=$(tahoe_hosts_get_field "$host_line" "name" || true)

  if [ -z "$host" ]; then
    echo "tahoe: host entry has no host field: $name" >&2
    return 1
  fi

  [ -n "$user" ] || user="$USER"

  local host_inject
  host_inject=$(tahoe_build_host_inject "$host_line")
  local env_inject
  env_inject=$(tahoe_build_env_inject "$env_file") || return 1

  if [ "$host" = "0.0.0.0" ] || [ "$name" = "local" ]; then
    { printf '%s\n' "$host_inject" "$env_inject"; cat "$script_file"; } | bash -s
    return $?
  fi

  tahoe_require_command ssh || return 1

  local ssh_opts
  ssh_opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null -o ConnectTimeout=10"
  local payload
  payload=$({ printf '%s\n' "$host_inject" "$env_inject"; cat "$script_file"; } | base64 -w0)

  if [ "$tty_mode" = "notty" ]; then
    if [ -n "$password" ]; then
      tahoe_require_command sshpass || return 1
      sshpass -p "$password" ssh $ssh_opts "${user}@${host}" "echo ${payload} | base64 -d | bash"
    else
      ssh $ssh_opts "${user}@${host}" "echo ${payload} | base64 -d | bash"
    fi
  else
    if [ -n "$password" ]; then
      tahoe_require_command sshpass || return 1
      sshpass -p "$password" ssh -tt $ssh_opts "${user}@${host}" "echo ${payload} | base64 -d | bash"
    else
      ssh -tt $ssh_opts "${user}@${host}" "echo ${payload} | base64 -d | bash"
    fi
  fi
}

tahoe_run_host() {
  local host_name
  host_name="$1"
  local env_file
  env_file="$2"
  local script_file
  script_file="$3"

  if [ ! -f "$env_file" ]; then
    echo "tahoe: config file not found: $env_file" >&2
    return 1
  fi

  local host_line
  host_line=$(tahoe_hosts_find "$host_name") || return 1

  tahoe_runner_exec "$host_line" "$script_file" "$env_file"
}

tahoe_run_host_capture() {
  local host_name
  host_name="$1"
  local env_file
  env_file="$2"
  local script_file
  script_file="$3"

  if [ ! -f "$env_file" ]; then
    echo "tahoe: config file not found: $env_file" >&2
    return 1
  fi

  local host_line
  host_line=$(tahoe_hosts_find "$host_name") || return 1

  tahoe_runner_exec "$host_line" "$script_file" "$env_file" "notty"
}
