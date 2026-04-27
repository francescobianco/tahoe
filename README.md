# Tahoe-LAFS Simple Provisioning

Provisioning minimale per cluster Tahoe-LAFS via Docker e SSH.

Il comando locale `tahoe` legge gli host da `~/.hosts`, prende la configurazione dal file `.tahoe` locale e lancia sul server remoto container Docker basati su `yafb/tahoe`.

## Setup locale

```bash
tahoe init
```

Questo crea:

```text
.tahoe
.tahoe.pem
.tahoe.key
```

Poi modifica `.tahoe` con hostname, introducer e porte del tuo cluster.
Le chiavi SFTP sono pronte subito; `SFTP_ROOTCAP=auto` fa creare al gateway il rootcap sulla grid al primo avvio.

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

Il comando stampa il `introducer.furl`. Copialo nel `.tahoe` locale come `INTRODUCER_FURL`.

## Storage node

```bash
tahoe node tahoe-1
```

Crea un nodo storage-only su Docker usando `TAHOE_BASE`, `NODE_PORT`, `INTRODUCER_FURL`, `SHARES_*` e `STORAGE_RESERVED_SPACE` dal `.env` locale.

## Gateway SFTP

```bash
tahoe gateway tahoe-1
```

Crea un gateway SFTP senza storage locale usando `GATEWAY_PORT`, `SFTP_PORT`, `SFTP_USER`, `SFTP_PUBLIC_KEY`, `SFTP_ROOTCAP`, `INTRODUCER_FURL` e `SHARES_*` dal `.tahoe` locale.

Tahoe-LAFS SFTP usa autenticazione a chiave pubblica. Puoi impostare direttamente `SFTP_PUBLIC_KEY`, oppure impostare `SFTP_PRIVATE_KEY` e il comando `tahoe` ricavera la public key localmente durante il deploy.

## Upload rapido

```bash
tahoe --config ./.tahoe upload ./backup.tar /incoming
```

Il comando usa direttamente `SFTP_HOST`, `SFTP_PORT`, `SFTP_USER` e `SFTP_PRIVATE_KEY` gia presenti nel file `.tahoe`. Non serve passare altro.

## Env file alternativo

```bash
tahoe node tahoe-1 --env-file ./prod.tahoe
```

## Host locale

`local` e un host built-in, quindi non richiede una riga in `~/.hosts`:

```bash
tahoe node local
```

## Logs remoti

```bash
tahoe introducer tahoe-1 --logs
tahoe node tahoe-1 --logs
tahoe gateway tahoe-1 --logs
```

## Test gateway

```bash
tahoe gateway tahoe-1 --test
```

Il test fa un upload SFTP reale dal client locale verso il gateway, scarica di nuovo il file e confronta gli hash. Usa `SFTP_HOST` dal `.tahoe`; se non e impostato usa l'host risolto da `~/.hosts`. Per `local` usa `127.0.0.1`.

Nel cluster di test il gateway espone anche la web UI Tahoe su `http://172.20.0.14:3456/` e viene avviato un file manager web separato basato su SFTPGo, collegato al gateway via SFTP, su `http://172.20.0.15:8080/web/client/login`.

## Accesso

```bash
sftp -P 8022 user@host
```
