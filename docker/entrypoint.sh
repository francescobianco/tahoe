#!/bin/sh
set -e

NODE_TYPE=$1
NODE_DIR=/node

set_sftpd_enabled() {
    VALUE="$1"
    python - "$NODE_DIR/tahoe.cfg" "$VALUE" <<'PY'
import sys

path, value = sys.argv[1], sys.argv[2]
lines = open(path).read().splitlines()
out = []
in_sftpd = False
done = False

for line in lines:
    stripped = line.strip()
    if stripped.startswith("[") and stripped.endswith("]"):
        if in_sftpd and not done:
            out.append(f"enabled = {value}")
            done = True
        in_sftpd = stripped == "[sftpd]"
        out.append(line)
        continue

    if in_sftpd and stripped.startswith("enabled"):
        out.append(f"enabled = {value}")
        done = True
        continue

    out.append(line)

if in_sftpd and not done:
    out.append(f"enabled = {value}")

open(path, "w").write("\n".join(out) + "\n")
PY
}

configure_tahoe_cfg() {
    python - "$NODE_DIR/tahoe.cfg" "$@" <<'PY'
import sys, configparser

path = sys.argv[1]
furl = sys.argv[2]
needed = sys.argv[3]
total = sys.argv[4]
happy = sys.argv[5]
storage_enabled = sys.argv[6]
reserved = sys.argv[7] if len(sys.argv) > 7 else None

cfg = configparser.RawConfigParser()
cfg.read(path)

cfg.set('client', 'introducer.furl', furl)
cfg.set('client', 'shares.needed', needed)
cfg.set('client', 'shares.total', total)
cfg.set('client', 'shares.happy', happy)
cfg.set('storage', 'enabled', storage_enabled)
if reserved is not None:
    cfg.set('storage', 'reserved_space', reserved)

with open(path, 'w') as f:
    cfg.write(f)
PY
}

ensure_sftp_config() {
    : "${SFTP_USER:?SFTP_USER was missing}"
    : "${SFTP_PUBLIC_KEY:?SFTP_PUBLIC_KEY was missing}"

    mkdir -p "$NODE_DIR/private"

    if [ ! -f "$NODE_DIR/private/ssh_host_rsa_key" ]; then
        ssh-keygen -q -t rsa -N "" -f "$NODE_DIR/private/ssh_host_rsa_key"
    fi

    if [ -z "${SFTP_ROOTCAP:-}" ] || [ "$SFTP_ROOTCAP" = "auto" ]; then
        if [ ! -s "$NODE_DIR/private/sftp.rootcap" ]; then
            rm -f "$NODE_DIR/private/sftp.rootcap"
            set_sftpd_enabled false
            tahoe run "$NODE_DIR" &
            TAHOE_PID=$!

            for i in $(seq 1 60); do
                if [ -f "$NODE_DIR/node.url" ]; then
                    break
                fi
                sleep 1
            done

            if [ ! -f "$NODE_DIR/node.url" ]; then
                kill "$TAHOE_PID" 2>/dev/null || true
                wait "$TAHOE_PID" 2>/dev/null || true
                echo "Unable to create SFTP rootcap: node.url was not created" >&2
                exit 1
            fi

            for i in $(seq 1 60); do
                if python - <<'PY'
import sys
from urllib.request import urlopen
try:
    urlopen("http://127.0.0.1:3456/", timeout=1).read(1)
except Exception:
    sys.exit(1)
PY
                then
                    break
                fi
                sleep 1
            done

            tahoe -d "$NODE_DIR" mkdir > "$NODE_DIR/private/sftp.rootcap.tmp"
            if [ ! -s "$NODE_DIR/private/sftp.rootcap.tmp" ]; then
                kill "$TAHOE_PID" 2>/dev/null || true
                wait "$TAHOE_PID" 2>/dev/null || true
                rm -f "$NODE_DIR/private/sftp.rootcap.tmp"
                echo "Unable to create SFTP rootcap: tahoe mkdir returned empty output" >&2
                exit 1
            fi
            mv "$NODE_DIR/private/sftp.rootcap.tmp" "$NODE_DIR/private/sftp.rootcap"
            kill "$TAHOE_PID" 2>/dev/null || true
            wait "$TAHOE_PID" 2>/dev/null || true
            set_sftpd_enabled true
        fi
        SFTP_ROOTCAP=$(cat "$NODE_DIR/private/sftp.rootcap")
    fi

    # Strip comment from public key: keep only key-type and base64 data
    sftp_pubkey=$(echo "$SFTP_PUBLIC_KEY" | cut -d' ' -f1,2)
    echo "$SFTP_USER $sftp_pubkey $SFTP_ROOTCAP" > "$NODE_DIR/private/accounts"

    if ! grep -q '^\[sftpd\]' "$NODE_DIR/tahoe.cfg"; then
        cat >> "$NODE_DIR/tahoe.cfg" <<EOF

[sftpd]
enabled = true
port = tcp:$SFTP_PORT:interface=0.0.0.0
accounts.file = private/accounts
EOF
    fi

    if ! grep -q '^host_pubkey_file =' "$NODE_DIR/tahoe.cfg"; then
        cat >> "$NODE_DIR/tahoe.cfg" <<EOF
host_pubkey_file = private/ssh_host_rsa_key.pub
EOF
    fi

    if ! grep -q '^host_privkey_file =' "$NODE_DIR/tahoe.cfg"; then
        cat >> "$NODE_DIR/tahoe.cfg" <<EOF
host_privkey_file = private/ssh_host_rsa_key
EOF
    fi
}

case "$NODE_TYPE" in
    introducer)
        if [ ! -f "$NODE_DIR/tahoe-introducer.tac" ]; then
            INTRODUCER_PORT="${INTRODUCER_PORT:-3458}"
            tahoe create-introducer \
                --port="tcp:${INTRODUCER_PORT}" \
                --location="tcp:${INTRODUCER_HOSTNAME}:${INTRODUCER_PORT}" \
                "$NODE_DIR"
        fi
        exec tahoe run --allow-stdin-close "$NODE_DIR"
        ;;

    node|storage)
        if [ ! -f "$NODE_DIR/tahoe.cfg" ]; then
            NODE_PORT="${NODE_PORT:-3457}"
            NODE_HOSTNAME="${TAHOE_NODE_HOSTNAME:-${INTRODUCER_HOSTNAME:-127.0.0.1}}"
            tahoe create-node \
                --port="tcp:${NODE_PORT}" \
                --location="tcp:${NODE_HOSTNAME}:${NODE_PORT}" \
                "$NODE_DIR"
            configure_tahoe_cfg \
                "$INTRODUCER_FURL" "$SHARES_NEEDED" "$SHARES_TOTAL" "$SHARES_HAPPY" \
                "true" "$STORAGE_RESERVED_SPACE"
        fi
        exec tahoe run --allow-stdin-close "$NODE_DIR"
        ;;

    gateway)
        if [ ! -f "$NODE_DIR/tahoe.cfg" ]; then
            NODE_PORT="${NODE_PORT:-3459}"
            NODE_HOSTNAME="${TAHOE_NODE_HOSTNAME:-${INTRODUCER_HOSTNAME:-127.0.0.1}}"
            tahoe create-node \
                --port="tcp:${NODE_PORT}" \
                --location="tcp:${NODE_HOSTNAME}:${NODE_PORT}" \
                "$NODE_DIR"
            configure_tahoe_cfg \
                "$INTRODUCER_FURL" "$SHARES_NEEDED" "$SHARES_TOTAL" "$SHARES_HAPPY" \
                "false"
        fi
        ensure_sftp_config
        exec tahoe run --allow-stdin-close "$NODE_DIR"
        ;;

    combined)
        if [ ! -f "$NODE_DIR/tahoe.cfg" ]; then
            NODE_PORT="${NODE_PORT:-3457}"
            NODE_HOSTNAME="${TAHOE_NODE_HOSTNAME:-${INTRODUCER_HOSTNAME:-127.0.0.1}}"
            tahoe create-node \
                --port="tcp:${NODE_PORT}" \
                --location="tcp:${NODE_HOSTNAME}:${NODE_PORT}" \
                "$NODE_DIR"
            configure_tahoe_cfg \
                "$INTRODUCER_FURL" "$SHARES_NEEDED" "$SHARES_TOTAL" "$SHARES_HAPPY" \
                "true" "$STORAGE_RESERVED_SPACE"
        fi
        ensure_sftp_config
        exec tahoe run --allow-stdin-close "$NODE_DIR"
        ;;

    *)
        echo "Usage: $0 [introducer|node|storage|gateway|combined]"
        exit 1
        ;;
esac