tahoe_hosts_get_field() {
  local line
  line="$1"
  local field
  field="$2"
  local pair
  local key
  local val

  for pair in $line; do
    key="${pair%%=*}"
    val="${pair#*=}"
    if [ "$key" = "$field" ]; then
      printf '%s\n' "$val"
      return 0
    fi
  done

  return 1
}

tahoe_hosts_parse() {
  local hosts_file
  hosts_file="${HOME}/.hosts"

  if [ ! -f "$hosts_file" ]; then
    echo "tahoe: hosts file not found: $hosts_file" >&2
    return 1
  fi

  awk '/\\$/ { sub(/\\$/, ""); printf "%s", $0; next } 1' "$hosts_file"
}

tahoe_hosts_list() {
  local line

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in \#*) continue ;; esac

    local name
    name=$(tahoe_hosts_get_field "$line" "name" || true)
    local host
    host=$(tahoe_hosts_get_field "$line" "host" || true)
    local user
    user=$(tahoe_hosts_get_field "$line" "user" || true)

    [ -n "$name" ] && printf "%-20s %s\n" "$name" "${user:+${user}@}${host}"
  done < <(tahoe_hosts_parse)
}

tahoe_hosts_find() {
  local host_name
  host_name="$1"
  local line

  if [ "$host_name" = "local" ]; then
    printf '%s\n' "name=local host=0.0.0.0 user=${USER}"
    return 0
  fi

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in \#*) continue ;; esac

    local entry_name
    entry_name=$(tahoe_hosts_get_field "$line" "name" || true)
    if [ "$entry_name" = "$host_name" ]; then
      printf '%s\n' "$line"
      return 0
    fi
  done < <(tahoe_hosts_parse)

  echo "tahoe: host not found: $host_name" >&2
  return 1
}

tahoe_build_host_inject() {
  local host_line
  host_line="$1"
  local pair
  local key
  local val

  for pair in $host_line; do
    key="${pair%%=*}"
    val="${pair#*=}"
    tahoe_is_identifier "$key" || continue
    printf 'declare tahoe_%s=%q\n' "$key" "$val"
  done
}
