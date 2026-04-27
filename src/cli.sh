tahoe_usage() {
  cat >&2 <<'EOF'
Usage:
  tahoe [--config <file>] [--hosts <file>] init
  tahoe [--config <file>] [--hosts <file>] introducer <host>
  tahoe [--config <file>] [--hosts <file>] node <host>
  tahoe [--config <file>] [--hosts <file>] gateway <host>
  tahoe [--config <file>] [--hosts <file>] introducer <host> --logs
  tahoe [--config <file>] [--hosts <file>] node <host> --logs
  tahoe [--config <file>] [--hosts <file>] gateway <host> --logs
  tahoe [--config <file>] [--hosts <file>] gateway <host> --test
  tahoe [--config <file>] upload <local-file> <remote-dir>
  tahoe [--config <file>] [--hosts <file>] hosts

Options:
  --config    Cluster config file (default: .tahoe)
  --hosts     Hosts file (default: ~/.hosts)

Commands:
  init        Create .tahoe, .tahoe.pem and .tahoe.key locally
  introducer  Deploy introducer; FURL is auto-saved to the config file
  node        Deploy a storage node container
  gateway     Deploy an SFTP gateway container
  upload      Upload a local file through the configured gateway
  hosts       List hosts from the hosts file
EOF
}

tahoe_cli_main() {
  while true; do
    case "${1:-}" in
      --config)
        [ -n "${2:-}" ] || { echo "tahoe: --config requires a file" >&2; return 1; }
        TAHOE_CONFIG_FILE="$2"
        shift 2
        ;;
      --hosts)
        [ -n "${2:-}" ] || { echo "tahoe: --hosts requires a file" >&2; return 1; }
        export TAHOE_HOSTS_FILE="$2"
        shift 2
        ;;
      *)
        break
        ;;
    esac
  done

  local config_file="${TAHOE_CONFIG_FILE:-.tahoe}"
  local command_name="${1:-}"

  case "$command_name" in
    ""|-h|--help)
      tahoe_usage
      return 0
      ;;
    hosts|--list)
      tahoe_hosts_list
      return $?
      ;;
    init)
      tahoe_init
      return $?
      ;;
    upload)
      if [ ! -f "$config_file" ]; then
        echo "tahoe: config file not found: $config_file" >&2
        echo "tahoe: run 'tahoe init' to create one" >&2
        return 1
      fi
      local local_file="${2:-}"
      local remote_dir="${3:-}"
      if [ -z "$local_file" ] || [ -z "$remote_dir" ]; then
        echo "tahoe: upload requires <local-file> and <remote-dir>" >&2
        tahoe_usage
        return 1
      fi
      tahoe_upload_file "$config_file" "$local_file" "$remote_dir"
      return $?
      ;;
    introducer|node|gateway)
      local host_name="${2:-}"
      if [ -z "$host_name" ]; then
        echo "tahoe: missing host name" >&2
        tahoe_usage
        return 1
      fi
      if [ ! -f "$config_file" ]; then
        echo "tahoe: config file not found: $config_file" >&2
        echo "tahoe: run 'tahoe init' to create one" >&2
        return 1
      fi
      local modifier="${3:-}"
      case "$modifier" in
        --logs)
          tahoe_with_remote_script "${command_name}-logs" "$host_name" "$config_file"
          ;;
        --test)
          if [ "$command_name" != "gateway" ]; then
            echo "tahoe: --test is only valid for gateway" >&2
            return 1
          fi
          tahoe_gateway_test "$host_name" "$config_file"
          ;;
        "")
          tahoe_with_remote_script "$command_name" "$host_name" "$config_file"
          ;;
        *)
          echo "tahoe: unknown option: $modifier" >&2
          tahoe_usage
          return 1
          ;;
      esac
      return $?
      ;;
    *)
      echo "tahoe: unknown command: $command_name" >&2
      tahoe_usage
      return 1
      ;;
  esac
}
