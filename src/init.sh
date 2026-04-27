tahoe_init() {
  local env_file
  env_file=".tahoe"
  local private_key
  private_key=".tahoe.pem"
  local public_key_file
  public_key_file=".tahoe.key"

  if [ -e "$env_file" ] || [ -e "$private_key" ] || [ -e "$public_key_file" ]; then
    echo "tahoe: init refused to overwrite existing .tahoe files" >&2
    echo "tahoe: remove .tahoe, .tahoe.pem and .tahoe.key if you want to reinitialize" >&2
    return 1
  fi

  tahoe_require_command ssh-keygen || return 1

  ssh-keygen -q -t ed25519 -N "" -f "$private_key" -C "tahoe-local"
  mv "${private_key}.pub" "$public_key_file"
  chmod 600 "$private_key"
  chmod 644 "$public_key_file"

  local public_key
  public_key=$(cat "$public_key_file")
  cat > "$env_file" <<EOF
TAHOE_BASE="/opt/tahoe"
TAHOE_IMAGE="yafb/tahoe"

INTRODUCER_HOSTNAME="your.server.hostname.or.ip"
INTRODUCER_PORT=3458
NODE_PORT=3457
GATEWAY_PORT=3459
TAHOE_WEB_PORT=3456
INTRODUCER_FURL="PASTE_HERE"

SHARES_NEEDED=1
SHARES_TOTAL=1
SHARES_HAPPY=1

STORAGE_RESERVED_SPACE=10G

SFTP_HOST="your.server.hostname.or.ip"
SFTP_PORT=8022
SFTP_USER="user"
SFTP_PRIVATE_KEY="$private_key"
SFTP_PUBLIC_KEY="$public_key"
SFTP_ROOTCAP="auto"
TAHOE_TEST_SIZE_MB=1
TAHOE_WEB_URL="http://your.server.hostname.or.ip:3456/"
FILEMANAGER_URL="http://your.server.hostname.or.ip:8080/web/client/login"
EOF

  echo "Created $env_file"
  echo "Created $private_key"
  echo "Created $public_key_file"
}
