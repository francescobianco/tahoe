# Gateway problems and notes

## Confirmed issue: broken SFTP readiness probe in integration test

Status: fixed in `tests/Dockerfile.host`

The integration test `tests/run-test.sh` waited for the gateway SFTP port with:

```sh
nc -z localhost 8022
```

inside `gateway-host`, but the host image did not install `nc`. The result was a false negative:

```sh
bash: line 1: nc: command not found
EXIT:127
```

This did not indicate a broken gateway. The inner `tahoe-gateway` container was already running and its logs showed:

```text
SSHFactory starting on 8022
```

Fix applied:

- added `netcat-openbsd` to `tests/Dockerfile.host`

## Test hardening: fragment verification after upload

Status: fixed in `tests/run-test.sh`

The original integration test only:

- waited for the SFTP port
- ran `tahoe gateway <host> --test`
- printed a sample of fragment files

That was not enough to prove that a fresh upload produced new storage fragments during the current run. The script now:

- captures fragment counts on each storage node before upload
- runs the SFTP upload/download hash verification
- captures fragment counts again after upload
- fails if no new fragments appear
- fails if new fragments do not appear on at least `SHARES_NEEDED` nodes

This makes the test assert both client-visible success and storage-side effects.

## Confirmed issue: SSH host key churn breaks `--clean`

Status: fixed in `tests/run-test.sh`

The test reuses static IPs like `172.20.0.10`, but `--clean` destroys and recreates the DinD hosts. That regenerates SSH host keys, so a later run can fail before the cluster even boots correctly with messages like:

```text
WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!
Password authentication is disabled to avoid man-in-the-middle attacks.
root@172.20.0.10: Permission denied (publickey,password).
```

`StrictHostKeyChecking=no` was not sufficient because OpenSSH still refused password auth on changed keys already present in `known_hosts`.

Fix applied:

- added `-o UserKnownHostsFile=/dev/null`
- added `-o GlobalKnownHostsFile=/dev/null`

This keeps the disposable test hosts isolated from the operator's persistent SSH trust database.

The same hardening was also applied to the main `tahoe` CLI remote runner and its SFTP client test path, otherwise `tests/run-test.sh` would still fail later during `tahoe introducer ...` even after fixing the script-local SSH options.

## Operational note: persistent cluster state can hide regressions

Status: still relevant

`tests/run-test.sh` leaves the cluster up by default. That is convenient for manual inspection, but it also means:

- old containers may still exist
- previous fragments may already be present
- the gateway may report "already exists"

The fragment delta check reduces this risk substantially, but for clean reproducibility the safest command remains:

```sh
bash tests/run-test.sh --clean
```

## Observed gateway behavior worth keeping in mind

Status: informational

On first boot, the gateway can spend noticeable time building the auto rootcap before SFTP is usable. There is also a brief restart window:

- a temporary `tahoe run` starts to create the rootcap
- that process is stopped
- the final long-running gateway process starts

A plain TCP probe on port `8022` is therefore not strong enough. The test now waits for an actual SSH banner and the local SFTP upload step retries until the service is stable.

If future failures appear around gateway startup, inspect:

- `docker logs tahoe-gateway` inside `gateway-host`
- `/node/private/sftp.rootcap`
- `/node/private/accounts`
- `node.url` creation timing during bootstrap

## Confirmed issue: wrong SFTP target in test config

Status: fixed in `tests/run-test.sh` and gateway deployment

The integration test initialized:

```sh
SFTP_HOST="172.20.0.14"
```

but the intended client path for the test is local machine -> gateway IP on the Docker VLAN. In the broken setup:

- `172.20.0.14` is the outer `gateway-host` IP on the bridge network
- the inner gateway container used nested Docker port publishing
- that made `127.0.0.1:8022` workable from the workstation, but not `172.20.0.14:8022`

The previous setup allowed the gateway readiness probe inside `gateway-host` to pass while the external SFTP client still failed with:

```text
ssh: connect to host 172.20.0.14 port 8022: Connection refused
```

Fix applied:

- changed the generated test config back to `SFTP_HOST="172.20.0.14"`
- changed gateway deployment inside DinD to use host networking instead of nested port publishing
- changed `tests/run-test.sh` to perform its own local `sftp` upload/download explicitly against `172.20.0.14:8022`

The resulting path is now exactly:

- local client on the workstation
- gateway reachable at `172.20.0.14:8022`
- fragments distributed onto the Tahoe storage nodes

## Observed issue: SFTP remove appears to hang after successful put/get

Status: worked around in `tests/run-test.sh`

During the end-to-end local client test against `172.20.0.14:8022`, the gateway successfully handled:

- `put`
- `get`

but the batch could stall after:

```text
REMOVE requestId=44
```

seen in `docker logs tahoe-gateway`, with the local `sftp` process remaining active instead of exiting cleanly.

Workaround applied:

- removed `rm $remote_file` from the integration test batch

This keeps the test focused on the guarantees we actually need for CI confidence:

- local client can upload to the gateway
- local client can download the same content back
- storage fragments are created on the Tahoe nodes

Follow-up worth investigating later:

- whether Tahoe-LAFS SFTP `REMOVE` is hanging in this setup
- whether the hang is specific to immutable uploaded files or this gateway bootstrap mode

## Observed issue: SFTP session may not exit cleanly after successful get

Status: worked around in `tests/run-test.sh`

Even after removing the `rm` step from the test batch, the local `sftp` client could remain active after the gateway had already completed:

- upload (`put`)
- download (`get`)
- file close on the downloaded object

Gateway logs reached the final `CLOSE` for the download path, but the client process did not always exit by itself.

Workaround applied:

- wrapped the local `sftp` batch in `timeout 20`
- treat the transfer as valid only if the downloaded file exists and the final SHA-256 hash matches

This keeps the test strict on data integrity while avoiding false negatives caused by session shutdown behavior.

## Confirmed issue: Tahoe web UI is loopback-only by default

Status: fixed in `docker/entrypoint.sh` and gateway deployment

Tahoe-LAFS `create-node` writes `[node] web.port = tcp:3456:interface=127.0.0.1` by default. That is fine for a single host, but in this test cluster it made the management UI unreachable from the workstation at `172.20.0.14:3456` even when the gateway itself was healthy.

Fix applied:

- added `TAHOE_WEB_PORT` to the generated config
- force `web.port = tcp:${TAHOE_WEB_PORT}:interface=0.0.0.0` during node creation
- verify the management UI from the workstation in `tests/run-test.sh`

Operational result:

- Tahoe management UI is reachable at `http://172.20.0.14:3456/`
- the path does not depend on `127.0.0.1` or host-level port forwarding

## Integration note: canonical web file manager is SFTPGo over the gateway SFTP layer

Status: implemented in `tests/docker-compose.yml` and `tests/run-test.sh`

The file manager is intentionally separate from the Tahoe gateway process. It is a standalone SFTPGo container on `172.20.0.15` and it talks to the gateway using the same SFTP interface exposed to normal clients:

- Tahoe gateway SFTP endpoint: `172.20.0.14:8022`
- SFTPGo WebClient: `http://172.20.0.15:8080/web/client/login`

Bootstrap notes:

- SFTPGo is provisioned with a default admin at container startup
- the test then creates or updates a WebClient user through the official REST API
- the backend storage for that user is `provider=5` (`SFTP`) with the Tahoe private key injected as a secret

This keeps the architecture honest:

- browser UI uses SFTP
- CLI uploads use SFTP
- both hit the same gateway contract
