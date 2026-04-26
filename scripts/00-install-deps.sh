#!/usr/bin/env bash
set -e

sudo apt update
sudo apt install -y python3 python3-venv python3-pip mailutils

sudo mkdir -p /opt/tahoe
sudo chown "$USER":"$USER" /opt/tahoe

python3 -m venv /opt/tahoe/venv
source /opt/tahoe/venv/bin/activate
pip install --upgrade pip
pip install tahoe-lafs
