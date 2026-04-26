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
```

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