# Configuration Requirements

This document explains the external configuration required by the one-click
menu. This project deploys the official `fractal-indexer`, `stake-indexer`, and
optional dry-run `proof-publisher`; it does not install or sync Fractald.

Official deployment templates are not vendored into this repository. At runtime,
the script fetches `fractal-bitcoin/fractal-indexer-deploy` into
`.official/fractal-indexer-deploy`, then writes local configuration inside that
directory.

## 1. Server And System

Recommended minimum:

- Linux x86_64 server.
- Docker and Docker Compose. The menu can install missing runtime dependencies
  on common distributions.
- `git`, `curl`, `tar`, and `zstd`.
- Recommended: `tmux` or `screen`, so long-running work survives SSH disconnects.
- At least 64 GB RAM for the indexer stack; 128 GB is preferred.
- At least 500 GB free SSD/NVMe space for the indexer stack. If Fractald is on
  the same host, reserve node storage separately.

The menu's resource setup only writes Docker container memory limits. It does
not change Fractald, CPU affinity, disk partitions, or node pruning policy.

## 2. Fractald Node Requirements

You must already have a usable Fractald node. The menu validates it from inside
Docker networking, not only from the host shell.

Required:

- Fractald is synced past the official snapshot height. The current snapshot
  height is `1753260`.
- `getblockchaininfo` works.
- `getblockhash` and `getblock` can read the snapshot height and stake reward
  start area.
- If the node is pruned, `pruneheight` must be less than or equal to `1753260`.
- RPC user and password exist; the password should be long and random.
- RPC and ZMQ are reachable from Docker containers.

Default container-visible endpoints:

```text
RPC:       http://fractald:8332
ZMQ block: tcp://fractald:10330
ZMQ tx:    tcp://fractald:10331
```

`fractald` is a Docker `host-gateway` alias. It is not a public DNS name.

If Fractald only listens on `127.0.0.1`, containers usually cannot reach it.
Bind Fractald to the Docker bridge or host private address, and protect it with
a firewall so RPC is not exposed publicly.

Example `bitcoin.conf` fragment:

```ini
server=1
rpcuser=bitcoinrpc
rpcpassword=REPLACE_WITH_LONG_RANDOM_PASSWORD
rpcport=8332
rpcbind=0.0.0.0
rpcallowip=127.0.0.1
rpcallowip=172.16.0.0/12
zmqpubrawblock=tcp://0.0.0.0:10330
zmqpubrawtx=tcp://0.0.0.0:10331
```

This example only shows container reachability. Production systems must use
firewall rules to restrict RPC/ZMQ inbound sources.

## 3. What The Menu Asks For

Menu option `1` is the recommended one-pass flow.

Environment and resources:

- Whether missing dependencies may be installed automatically.
- Whether official source repositories should be cloned for research. Docker
  deployment does not require source checkouts.
- Resource mode: automatic limits based on currently available memory, or manual
  container memory limits.

Fractald connection:

- Container-visible Fractald RPC URL.
- Container-visible ZMQ block URL.
- Container-visible ZMQ tx URL.
- RPC user.
- RPC password.

Snapshot and startup:

- Whether to restore the official `fractal-indexer` snapshot. Normal deployments
  should choose yes.
- Whether existing `fractal-indexer/data` should be backed up.
- Whether old containers should be stopped to avoid Compose conflicts.
- Wait timeout.
- Whether `stake-indexer` may start before statehash readiness. Do not enable
  this for normal operation; it is only for observation/debugging.

Optional proof-publisher dry-run:

- Fractald RPC URL, user, and password for proof-publisher.
- Indexer owner private key WIF.
- Change address.
- Reward address.
- Indexer name.
- Existing `indexer_id`. Leave empty before registration; set the real value
  only after registration exists.
- UniSat Open API key.

The current menu always writes:

```json
"dry_run": true,
"disable_broadcast": true
```

So proof-publisher is only for configuration preparation and health checks. It
does not perform real registration, signing, or broadcasting.

## 4. Generated Local Files

The menu generates local runtime files. Do not commit them:

- `.official/fractal-indexer-deploy/fractal-indexer/conf/indexer/chain.yaml`
- `.official/fractal-indexer-deploy/stake-indexer/conf/indexer/chain.yaml`
- `.official/fractal-indexer-deploy/proof-publisher/config.json`
- `.official/fractal-indexer-deploy/fractal-indexer/docker-compose.override.yaml`
- `.official/fractal-indexer-deploy/stake-indexer/docker-compose.override.yaml`
- `.official/fractal-indexer-deploy/fractal-indexer/docker-compose.menu.yaml`
- `.official/fractal-indexer-deploy/stake-indexer/docker-compose.menu.yaml`
- `data/`
- `logs/`

Generated files can contain RPC passwords, private keys, or API keys. Do not
paste them into public issues, chats, or logs.

## 5. Ports

This project commonly uses:

```text
8000  fractal-indexer API
9637  stake-indexer API
8080  proof-publisher API, optional
9222  fractal-indexer internal pika-brc20
9432  stake-indexer internal PostgreSQL
9379  stake-indexer internal Redis
```

The menu tries to keep internal datastore ports bound to `127.0.0.1`. Public API
exposure depends on your firewall and reverse-proxy policy.

Fractald ports `8332`, `10330`, and `10331` are provided by your node, not by
this project.

## 6. Values You Usually Should Not Edit

For normal deployments, do not manually change:

- Official Docker image names.
- Heights and reward rules in `stake-indexer/conf/indexer/config.yaml`.
- The `fractal-indexer` snapshot height, unless an official compatible snapshot
  is released.
- `runtime.dry_run=false` or `disable_broadcast=false`.

If official rules change, update this repository and rerun `--doctor` and
`--self-test`.

To update only the official deployment templates:

```bash
bash scripts/deploy-menu.sh --sync-official
```

To pin a specific official tag, branch, or commit:

```bash
OFFICIAL_DEPLOY_REF=<tag-or-commit> bash scripts/deploy-menu.sh --sync-official
```

## 7. Preflight Checks

Before deployment:

```bash
bash scripts/deploy-menu.sh --doctor
```

Only validate Fractald RPC/ZMQ and snapshot compatibility:

```bash
bash scripts/deploy-menu.sh --validate-rpc
```

After deployment:

```bash
bash scripts/deploy-menu.sh --health
```
