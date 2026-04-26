Perfetto, ti preparo **una repo completa, minimale e pronta da copiare**.
È pensata per essere:

* semplice (solo bash + tahoe)
* ripetibile
* sicura (senza segreti dentro)

---

# 📦 STRUTTURA REPO

```text
tahoe-simple-provisioning/
├── README.md
├── .env.example
├── .gitignore
├── scripts/
│   ├── 00-install-deps.sh
│   ├── 10-create-introducer.sh
│   ├── 20-create-storage-node.sh
│   ├── 30-create-gateway.sh
│   ├── 40-create-sftp-user.sh
│   ├── 50-run-node.sh
│   └── 60-healthcheck.sh
```

---

# 📄 README.md

````markdown
# Tahoe-LAFS Simple Provisioning

Provisioning minimale per cluster Tahoe-LAFS con:
- introducer
- storage nodes
- gateway SFTP
- healthcheck automatico

## Setup

```bash
cp .env.example .env
nano .env
````

## Installazione

```bash
./scripts/00-install-deps.sh
```

## Introducer

```bash
./scripts/10-create-introducer.sh
```

Copia il `introducer.furl` e mettilo nel `.env`

## Storage node

```bash
./scripts/20-create-storage-node.sh
./scripts/50-run-node.sh storage
```

## Gateway

```bash
./scripts/30-create-gateway.sh
./scripts/40-create-sftp-user.sh
./scripts/50-run-node.sh gateway
```

## Healthcheck

```bash
crontab -e
```

```
0 * * * * /path/scripts/60-healthcheck.sh
```

## Accesso

```bash
sftp -P 8022 user@host
```

````

---

# ⚙️ .env.example

```bash
TAHOE_BASE="/opt/tahoe"
TAHOE_NODE_NAME="node-01"

INTRODUCER_FURL="PASTE_HERE"

SHARES_NEEDED=3
SHARES_TOTAL=10
SHARES_HAPPY=7

SFTP_PORT=8022
SFTP_USER="user"
SFTP_PASSWORD="password"

HEALTHCHECK_MAIL_TO="you@example.com"
````

---

# 🚫 .gitignore

```gitignore
.env
private/
*.furl
*.cap
node.url
accounts
*.key
*.pem
*.secret
```

---

# 📜 scripts/00-install-deps.sh

```bash
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
```

---

# 📜 scripts/10-create-introducer.sh

```bash
#!/usr/bin/env bash
set -e

source .env
source "$TAHOE_BASE/venv/bin/activate"

NODE="$TAHOE_BASE/introducer"

tahoe create-introducer "$NODE"

echo "Introducer creato:"
cat "$NODE/private/introducer.furl"
```

---

# 📜 scripts/20-create-storage-node.sh

```bash
#!/usr/bin/env bash
set -e

source .env
source "$TAHOE_BASE/venv/bin/activate"

NODE="$TAHOE_BASE/storage-$TAHOE_NODE_NAME"

tahoe create-node "$NODE"

cat >> "$NODE/tahoe.cfg" <<EOF

[client]
introducer.furl = $INTRODUCER_FURL

[storage]
enabled = true
reserved_space = 1G
EOF

echo "Storage node creato: $NODE"
```

---

# 📜 scripts/30-create-gateway.sh

```bash
#!/usr/bin/env bash
set -e

source .env
source "$TAHOE_BASE/venv/bin/activate"

NODE="$TAHOE_BASE/gateway"

tahoe create-node "$NODE"

cat >> "$NODE/tahoe.cfg" <<EOF

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

mkdir -p "$NODE/private"
```

---

# 📜 scripts/40-create-sftp-user.sh

```bash
#!/usr/bin/env bash
set -e

source .env

NODE="$TAHOE_BASE/gateway"
ACCOUNTS="$NODE/private/accounts"

echo "$SFTP_USER:$SFTP_PASSWORD:root" > "$ACCOUNTS"

echo "Utente SFTP creato"
```

---

# 📜 scripts/50-run-node.sh

```bash
#!/usr/bin/env bash
set -e

source .env
source "$TAHOE_BASE/venv/bin/activate"

TYPE=$1

if [ "$TYPE" = "storage" ]; then
    NODE="$TAHOE_BASE/storage-$TAHOE_NODE_NAME"
elif [ "$TYPE" = "gateway" ]; then
    NODE="$TAHOE_BASE/gateway"
elif [ "$TYPE" = "introducer" ]; then
    NODE="$TAHOE_BASE/introducer"
else
    echo "Uso: $0 [storage|gateway|introducer]"
    exit 1
fi

tahoe run "$NODE"
```

---

# 📜 scripts/60-healthcheck.sh

```bash
#!/usr/bin/env bash
set -e

source .env
source "$TAHOE_BASE/venv/bin/activate"

TMP=$(mktemp -d)
LOCAL="$TMP/test.bin"
DOWN="$TMP/down.bin"
REMOTE="tahoe:healthcheck/test.bin"

fail() {
  echo "$1" | mail -s "Tahoe FAILED" "$HEALTHCHECK_MAIL_TO"
  exit 1
}

dd if=/dev/urandom of="$LOCAL" bs=1M count=32 status=none

tahoe mkdir tahoe:healthcheck || true
tahoe put "$LOCAL" "$REMOTE" || fail "upload"
tahoe check "$REMOTE" || fail "check"
tahoe get "$REMOTE" "$DOWN" || fail "download"

H1=$(sha256sum "$LOCAL" | cut -d' ' -f1)
H2=$(sha256sum "$DOWN" | cut -d' ' -f1)

[ "$H1" = "$H2" ] || fail "hash mismatch"

rm -rf "$TMP"
echo "OK"
```

---

# 🚀 COME USARLA (veloce)

```bash
git init
cp -r tahoe-simple-provisioning/* .
chmod +x scripts/*.sh

cp .env.example .env
nano .env
```

Poi:

```bash
./scripts/00-install-deps.sh
./scripts/10-create-introducer.sh
```

👉 copia il furl dentro `.env`

```bash
./scripts/20-create-storage-node.sh
./scripts/50-run-node.sh storage
```

Gateway:

```bash
./scripts/30-create-gateway.sh
./scripts/40-create-sftp-user.sh
./scripts/50-run-node.sh gateway
```

---

# ⚠️ NOTE IMPORTANTI

* NON committare `.env`
* NON committare `private/`
* NON committare `introducer.furl`

---

# 💡 Upgrade futuri (quando vuoi)

* systemd service
* dockerizzazione
* healthcheck avanzato
* multi-gateway
* TLS davanti a SFTP

---

Se vuoi al prossimo step possiamo:

* aggiungere **systemd automatico**
* oppure **cluster multi-node reale con script distribuiti**
* oppure **monitoring serio (Prometheus/Grafana)**
