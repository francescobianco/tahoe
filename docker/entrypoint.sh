#!/bin/sh
set -e

NODE_TYPE=$1
NODE_DIR=/node

case "$NODE_TYPE" in
    introducer)
        if [ ! -f "$NODE_DIR/tahoe-introducer.tac" ]; then
            INTRODUCER_PORT="${INTRODUCER_PORT:-3458}"
            tahoe create-introducer \
                --port="tcp:${INTRODUCER_PORT}" \
                --location="tcp:${INTRODUCER_HOSTNAME}:${INTRODUCER_PORT}" \
                "$NODE_DIR"
        fi
        exec tahoe run "$NODE_DIR"
        ;;

    node|storage)
        if [ ! -f "$NODE_DIR/tahoe.cfg" ]; then
            NODE_PORT="${NODE_PORT:-3457}"
            NODE_HOSTNAME="${TAHOE_NODE_HOSTNAME:-${INTRODUCER_HOSTNAME:-127.0.0.1}}"
            tahoe create-node \
                --port="tcp:${NODE_PORT}" \
                --location="tcp:${NODE_HOSTNAME}:${NODE_PORT}" \
                "$NODE_DIR"
            cat >> "$NODE_DIR/tahoe.cfg" <<EOF

[client]
introducer.furl = $INTRODUCER_FURL
shares.needed = $SHARES_NEEDED
shares.total = $SHARES_TOTAL
shares.happy = $SHARES_HAPPY

[storage]
enabled = true
reserved_space = $STORAGE_RESERVED_SPACE
EOF
        fi
        exec tahoe run "$NODE_DIR"
        ;;

    gateway)
        if [ ! -f "$NODE_DIR/tahoe.cfg" ]; then
            NODE_PORT="${NODE_PORT:-3459}"
            NODE_HOSTNAME="${TAHOE_NODE_HOSTNAME:-${INTRODUCER_HOSTNAME:-127.0.0.1}}"
            tahoe create-node \
                --port="tcp:${NODE_PORT}" \
                --location="tcp:${NODE_HOSTNAME}:${NODE_PORT}" \
                "$NODE_DIR"
            cat >> "$NODE_DIR/tahoe.cfg" <<EOF

[client]
introducer.furl = $INTRODUCER_FURL
shares.needed = $SHARES_NEEDED
shares.total = $SHARES_TOTAL
shares.happy = $SHARES_HAPPY

[storage]
enabled = false

[sftpd]
enabled = true
port = tcp:$SFTP_PORT:interface=0.0.0.0
accounts.file = private/accounts
EOF
            mkdir -p "$NODE_DIR/private"
            echo "$SFTP_USER:$SFTP_PASSWORD:root" > "$NODE_DIR/private/accounts"
        fi
        exec tahoe run "$NODE_DIR"
        ;;

    combined)
        if [ ! -f "$NODE_DIR/tahoe.cfg" ]; then
            NODE_PORT="${NODE_PORT:-3457}"
            NODE_HOSTNAME="${TAHOE_NODE_HOSTNAME:-${INTRODUCER_HOSTNAME:-127.0.0.1}}"
            tahoe create-node \
                --port="tcp:${NODE_PORT}" \
                --location="tcp:${NODE_HOSTNAME}:${NODE_PORT}" \
                "$NODE_DIR"
            cat >> "$NODE_DIR/tahoe.cfg" <<EOF

[client]
introducer.furl = $INTRODUCER_FURL
shares.needed = $SHARES_NEEDED
shares.total = $SHARES_TOTAL
shares.happy = $SHARES_HAPPY

[storage]
enabled = true
reserved_space = $STORAGE_RESERVED_SPACE

[sftpd]
enabled = true
port = tcp:$SFTP_PORT:interface=0.0.0.0
accounts.file = private/accounts
EOF
            mkdir -p "$NODE_DIR/private"
            echo "$SFTP_USER:$SFTP_PASSWORD:root" > "$NODE_DIR/private/accounts"
        fi
        exec tahoe run "$NODE_DIR"
        ;;

    *)
        echo "Usage: $0 [introducer|node|storage|gateway|combined]"
        exit 1
        ;;
esac
