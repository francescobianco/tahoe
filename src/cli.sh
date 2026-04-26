tahoe_usage() {
  cat >&2 <<'EOF'
Usage:
  tahoe introducer <host> [--env-file <file>]
  tahoe node <host> [--env-file <file>]
  tahoe gateway <host> [--env-file <file>]
  tahoe introducer <host> --logs [--env-file <file>]
  tahoe node <host> --logs [--env-file <file>]
  tahoe gateway <host> --logs [--env-file <file>]
  tahoe gateway <host> --test [--env-file <file>]
  tahoe hosts

Commands:
  introducer  Run a Tahoe introducer container on the selected host
  node        Run a storage-only Tahoe node container on the selected host
  gateway     Run an SFTP gateway container on the selected host
  hosts       List hosts from ~/.hosts
EOF
}

tahoe_cli_main() {
  local command_name
  command_name="$1"

  case "$command_name" in
    ""|-h|--help)
      tahoe_usage
      return 0
      ;;
    hosts|--list)
      tahoe_hosts_list
      return $?
      ;;
    introducer|node|gateway)
      local host_name
      host_name="$2"
      if [ -z "$host_name" ]; then
        echo "tahoe: missing host name" >&2
        tahoe_usage
        return 1
      fi

      local env_file
      if [ "$command_name" = "gateway" ] && env_file=$(tahoe_parse_test_env_file "$3" "$4" "$5"); then
        tahoe_gateway_test "$host_name" "$env_file"
      elif env_file=$(tahoe_parse_logs_env_file "$3" "$4" "$5"); then
        tahoe_with_remote_script "${command_name}-logs" "$host_name" "$env_file"
      else
        env_file=$(tahoe_parse_env_file "$3" "$4") || return 1
        tahoe_with_remote_script "$command_name" "$host_name" "$env_file"
      fi
      return $?
      ;;
    *)
      echo "tahoe: unknown command: $command_name" >&2
      tahoe_usage
      return 1
      ;;
  esac
}
