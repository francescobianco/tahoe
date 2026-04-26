# Tahoe-LAFS Simple Provisioning

Provisioning minimale per cluster Tahoe-LAFS via Docker e SSH.

Il comando locale `tahoe` legge gli host da `~/.hosts`, prende la configurazione da un file `.env` locale e lancia sul server remoto container Docker basati su `yafb/tahoe`.

## Setup locale

```bash
cp .env.example .env
nano .env
```

Configura anche `~/.hosts`:

```text
name=tahoe-1 host=192.0.2.10 user=root
```

Se serve password SSH, puoi aggiungere `password=...`; altrimenti viene usato SSH con chiave.

Verifica gli host disponibili:

```bash
tahoe hosts
```

Di default i comandi usano `TAHOE_IMAGE=yafb/tahoe`.

Per buildare l'immagine locale:

```bash
docker build -t yafb/tahoe -f docker/Dockerfile docker
```

## Introducer

```bash
tahoe introducer tahoe-1
```

Il comando stampa il `introducer.furl`. Copialo nel `.env` locale come `INTRODUCER_FURL`.

## Storage node

```bash
tahoe node tahoe-1
```

Crea un nodo storage-only su Docker usando `TAHOE_BASE`, `NODE_PORT`, `INTRODUCER_FURL`, `SHARES_*` e `STORAGE_RESERVED_SPACE` dal `.env` locale.

## Gateway SFTP

```bash
tahoe gateway tahoe-1
```

Crea un gateway SFTP senza storage locale usando `GATEWAY_PORT`, `SFTP_PORT`, `SFTP_USER`, `SFTP_PASSWORD`, `INTRODUCER_FURL` e `SHARES_*` dal `.env` locale.

## Env file alternativo

```bash
tahoe node tahoe-1 --env-file ./prod.env
```

## Logs remoti

```bash
tahoe inspector tahoe-1 --logs
```

Se vuoi puntare un container specifico, imposta `TAHOE_LOGS_CONTAINER` nel file `.env`.

## Accesso

```bash
sftp -P 8022 user@host
```
