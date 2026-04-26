#!/usr/bin/env bash
set -e

TAHOE_BASE="${TAHOE_BASE:-/opt/tahoe}"
VENV="$TAHOE_BASE/venv"

check_tahoe() {
    "$VENV/bin/python" -c "from allmydata.scripts.runner import run" 2>/dev/null
}

if [ -d "$VENV" ]; then
    if check_tahoe; then
        echo "Venv already set up and tahoe is working — nothing to do."
        exit 0
    fi

    echo ""
    echo "WARNING: venv found at $VENV but tahoe is broken or incomplete."
    echo "Recreating the venv will delete $VENV."
    echo "Node data in $TAHOE_BASE (introducer, storage, gateway) will NOT be touched,"
    echo "but any tahoe process running against this venv will stop working."
    echo ""
    read -r -p "Recreate venv? [y/N] " answer </dev/tty
    case "$answer" in
        [yY]*) rm -rf "$VENV" ;;
        *) echo "Aborted."; exit 1 ;;
    esac
fi

sudo apt update
# prefer python3.9 (available on Ubuntu 20.04 without extra PPAs), fall back to python3.8
if apt-cache show python3.9 &>/dev/null; then
    PYTHON=python3.9
    sudo apt install -y python3.9 python3.9-venv python3.9-dev build-essential
else
    PYTHON=python3
    sudo apt install -y python3 python3-venv python3-dev build-essential
fi

sudo mkdir -p "$TAHOE_BASE"
sudo chown "$USER":"$USER" "$TAHOE_BASE"

"$PYTHON" -m venv "$VENV"
source "$VENV/bin/activate"
pip install --upgrade pip
# pin known incompatible transitive deps before tahoe-lafs
pip install 'zfec<1.6.0.0' 'attrs<22.2.0'
pip install tahoe-lafs

echo "Done. Tahoe installed at $VENV using $("$PYTHON" --version)."
