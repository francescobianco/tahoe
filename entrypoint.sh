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

    node)
        if [ ! -f "$NODE_DIR/tahoe.cfg" ]; then
            tahoe create-node "$NODE_DIR"
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
        echo "Usage: $0 [introducer|node]"
        exit 1
        ;;
esac
