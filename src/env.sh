tahoe_is_identifier() {
  local name
  name="$1"

  case "$name" in
    ""|[0-9]*|*[!A-Za-z0-9_]*)
      return 1
      ;;
  esac

  return 0
}

tahoe_build_env_inject() {
  local env_file
  env_file="$1"
  local line
  local key
  local val
  local sftp_private_key
  local has_sftp_public_key
  has_sftp_public_key=0

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|\#*) continue ;; esac
    key="${line%%=*}"
    val="${line#*=}"

    if ! tahoe_is_identifier "$key"; then
      echo "tahoe: invalid config key: $key" >&2
      return 1
    fi

    case "$val" in
      \"*\") val="${val#\"}"; val="${val%\"}" ;;
      \'*\') val="${val#\'}"; val="${val%\'}" ;;
    esac

    if [ "$key" = "SFTP_PRIVATE_KEY" ]; then
      sftp_private_key="$val"
    fi
    if [ "$key" = "SFTP_PUBLIC_KEY" ]; then
      has_sftp_public_key=1
    fi

    printf 'declare %s=%q\n' "$key" "$val"
  done < "$env_file"

  if [ "$has_sftp_public_key" -eq 0 ] && [ -n "$sftp_private_key" ]; then
    if [ ! -f "$sftp_private_key" ]; then
      echo "tahoe: SFTP_PRIVATE_KEY not found: $sftp_private_key" >&2
      return 1
    fi
    tahoe_require_command ssh-keygen || return 1
    local public_key
    public_key=$(ssh-keygen -y -f "$sftp_private_key")
    printf 'declare SFTP_PUBLIC_KEY=%q\n' "$public_key"
  fi
}

tahoe_config_set() {
  local config_file="$1"
  local key="$2"
  local val="$3"

  if grep -q "^${key}=" "$config_file"; then
    sed -i "s|^${key}=.*|${key}=\"${val}\"|" "$config_file"
  else
    printf '%s="%s"\n' "$key" "$val" >> "$config_file"
  fi
}

tahoe_load_env_file() {
  local env_file
  env_file="$1"

  if [ ! -f "$env_file" ]; then
    echo "tahoe: config file not found: $env_file" >&2
    return 1
  fi

  set -a
  . "$env_file"
  set +a
}
