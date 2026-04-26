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

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|\#*) continue ;; esac
    key="${line%%=*}"
    val="${line#*=}"

    if ! tahoe_is_identifier "$key"; then
      echo "tahoe: invalid env key: $key" >&2
      return 1
    fi

    case "$val" in
      \"*\") val="${val#\"}"; val="${val%\"}" ;;
      \'*\') val="${val#\'}"; val="${val%\'}" ;;
    esac

    printf 'declare %s=%q\n' "$key" "$val"
  done < "$env_file"
}

tahoe_parse_env_file() {
  local first_arg
  first_arg="$1"
  local second_arg
  second_arg="$2"

  if [ "$first_arg" = "--env-file" ]; then
    if [ -z "$second_arg" ]; then
      echo "tahoe: --env-file requires a file" >&2
      return 1
    fi
    printf '%s\n' "$second_arg"
    return 0
  fi

  if [ -n "$first_arg" ]; then
    echo "tahoe: unexpected argument: $first_arg" >&2
    return 1
  fi

  printf '%s\n' ".env"
}

tahoe_parse_logs_env_file() {
  local first_arg
  first_arg="$1"
  local second_arg
  second_arg="$2"
  local third_arg
  third_arg="$3"

  if [ "$first_arg" != "--logs" ]; then
    return 1
  fi

  tahoe_parse_env_file "$second_arg" "$third_arg"
}

tahoe_parse_test_env_file() {
  local first_arg
  first_arg="$1"
  local second_arg
  second_arg="$2"
  local third_arg
  third_arg="$3"

  if [ "$first_arg" != "--test" ]; then
    return 1
  fi

  tahoe_parse_env_file "$second_arg" "$third_arg"
}

tahoe_load_env_file() {
  local env_file
  env_file="$1"

  if [ ! -f "$env_file" ]; then
    echo "tahoe: env file not found: $env_file" >&2
    return 1
  fi

  set -a
  . "$env_file"
  set +a
}
