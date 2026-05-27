# Interactive CLI Deployment Menu

This repository includes an interactive Bash menu for operators who want a guided
deployment path instead of running every Compose command manually. The menu
supports English and Chinese.

Start it from the repository root:

```bash
bash scripts/deploy-menu.sh
```

For long-running first deployments, prefer the persistent wrapper so snapshot
restore and catch-up work survive SSH disconnects:

```bash
bash scripts/run-menu-persistent.sh
```

If the SSH session disconnects, reattach with:

```bash
tmux attach -t fractal-indexer-oneclick
```

Non-interactive checks:

```bash
bash scripts/deploy-menu.sh --check
bash scripts/deploy-menu.sh --validate-rpc
bash scripts/deploy-menu.sh --validate-statehash
bash scripts/deploy-menu.sh --doctor
bash scripts/deploy-menu.sh --beginner
bash scripts/deploy-menu.sh --self-test
bash scripts/deploy-menu.sh --health
```

## What The Menu Does

- asks for English or Chinese on startup
- offers a beginner mode that diagnoses Fractald, applies safe defaults, and
  usually asks only for RPC password confirmation plus final approval
- keeps an advanced one-pass deployment wizard for full customization
- detects OS, package manager, CPU cores, memory, free disk, Docker, and Docker
  Compose
- detects local Fractald config when possible and pre-fills RPC/ZMQ prompts
- validates Fractald RPC from inside a Docker container before the automatic
  flow restores the snapshot or starts services
- verifies standard Fractald `getblockhash`/`getblock` access at the snapshot
  and reward-start heights, so official `stake-indexer` v0.1.1 RPC
  compatibility and pruned-node block availability are checked before startup
- exposes the same RPC and snapshot compatibility test as
  `bash scripts/deploy-menu.sh --validate-rpc`
- exposes a read-only stake readiness check as
  `bash scripts/deploy-menu.sh --validate-statehash`; it requires a confirmed
  block hash and state hash at the official reward-start height
- exposes a non-destructive readiness report as
  `bash scripts/deploy-menu.sh --doctor`
- includes a non-destructive internal helper self-test for maintainers as
  `bash scripts/deploy-menu.sh --self-test`
- checks pruned Fractald nodes still retain the snapshot height before using
  the official snapshot
- fetches or fast-forwards the official `fractal-indexer-deploy` bundle under
  `.official/fractal-indexer-deploy`
- can install missing runtime dependencies on supported Linux systems
- can clone optional official source repositories for research
- can generate local Docker Compose resource overrides automatically or manually;
  auto mode uses currently available memory instead of total machine memory
- generates ignored runtime Compose files that keep official images/configuration
  but bind Pika BRC20, PostgreSQL, and Redis host ports to `127.0.0.1` by
  default
- checks required tools: Docker, Docker Compose, `curl`, `tar`, `zstd`, and `git`
- checks that the official `init.sh` ownership steps can run as root or through
  usable `sudo` before deployment reaches data initialization
- reports CRLF line endings in official helper scripts without changing tracked
  files, then uses temporary LF-normalized copies only when running initialization
- creates local `chain.yaml` files for `fractal-indexer` and `stake-indexer`
- validates official Fractal images, the official `stake-indexer` pinned image,
  and the reward start height from the fetched official config
- pulls official indexer images when the registry is reachable, while keeping
  startup diagnostics for stale local containers
- warns during preflight when free disk is below the default snapshot restore
  guard
- warns during preflight when common service ports already have local listeners
- restores the official `fractal-indexer` snapshot at height `1753260`
- when snapshot restore is deliberately disabled on an empty deployment, checks
  Fractald block height `0` and runs the official from-genesis database
  initialization command; pruned nodes cannot use this empty-data path
- initializes and starts the `fractal-indexer` Compose stack
- waits for the Fractal indexer API and the FIP-101 state hash endpoint
- initializes and starts the `stake-indexer` Compose stack
- prepares `proof-publisher/config.json` in dry-run mode
  using scan defaults from the official `proof-publisher/config.example.json`
- shows service status, logs, and HTTP health checks
- reports internal datastore ports as unhealthy if they are exposed beyond
  localhost under the default security mode

## Safety Defaults

The menu is designed for open-source use and avoids hard-coding any operator
server details.

- RPC credentials are prompted locally and written only to ignored config files.
- Menu-generated `chain.yaml` files are restricted to mode `0600` for the
  official indexer container user (`uid 1000`); generated proof-publisher
  configuration is restricted to mode `0600` for its official container user
  (`uid 10001`). Protected configuration backups are also restricted to `0600`.
- Existing config files are backed up before being overwritten.
- Local config backup files that may contain RPC credentials are ignored by git.
- Existing `fractal-indexer/data` is not removed. For snapshot restore, it is
  moved to a timestamped backup only when the operator explicitly enables that
  option in the wizard. In the manual snapshot menu, typing `RESTORE` is still
  required.
- Snapshot restore is staged in a temporary directory first. If download or
  extraction fails, the partial staging directory is removed and existing data is
  left unchanged.
- An empty deployment cannot silently skip both the snapshot and official
  database initialization. With snapshot restore disabled, the menu permits a
  new from-genesis build only when Fractald can actually serve block height `0`.
- `proof-publisher` is prepared with `runtime.dry_run=true` and
  `runtime.disable_broadcast=true`.
- The menu does not start real transaction broadcasting automatically.
- The future one-click operator registration entry is visible, but it safely
  refuses execution until official third-party registration rules are public and
  stable.
- If proof-publisher startup is selected, the wizard checks the official image
  before restoring the snapshot or starting indexer services, then waits for its
  health endpoint before finishing.
- The menu is official-version-only. If the official proof-publisher image is
  unavailable, it stops instead of building a local source checkout. If the
  registry pull fails, it only continues when a locally cached official
  registry digest is already present.
- The menu does not install or sync Fractald itself. It only uses the Fractald
  RPC and ZMQ endpoints you provide.
- The menu defaults internal datastore host ports to local access only:
  `127.0.0.1:9222` for Pika BRC20, `127.0.0.1:9432` for PostgreSQL, and
  `127.0.0.1:9379` for Redis. This does not change official images or protocol
  configuration. API ports remain as defined by the official Compose files.
- To deliberately retain the official public host-port bindings, run with
  `INTERNAL_PORT_BIND_MODE=official` only after applying firewall controls.
- The official API ports (`8000`, `9637`, and optional `8080`) are not hidden by
  this internal-store protection. Expose them publicly only when intended and
  restrict them with firewall or reverse-proxy policy as appropriate.
- The default RPC port is `8332`, matching common Fractald deployments. If your
  node uses `10332`, enter `http://fractald:10332` in the prompt or run with
  `DEFAULT_RPC_PORT=10332`.
- Snapshot restore requires enough free disk near the deploy directory. The
  default guard is `SNAPSHOT_MIN_FREE_GB=400`; lower it only after verifying the
  final snapshot data size on your target machine.
- Resource overrides are written to ignored local files. The stake-indexer
  override also adds the `fractald:host-gateway` alias used by the generated
  `chain.yaml`, so the official Compose file does not need to be patched:
  `fractal-indexer/docker-compose.override.yaml` and
  `stake-indexer/docker-compose.override.yaml`.
- Runtime Compose copies are also ignored local files:
  `fractal-indexer/docker-compose.menu.yaml` and
  `stake-indexer/docker-compose.menu.yaml`. They are regenerated before startup
  and only adjust the internal datastore host port bindings described above.
- After these runtime files exist, continue using this menu for startup,
  shutdown, status, and logs, or include both `-f docker-compose.menu.yaml -f
  docker-compose.override.yaml` in manual Compose commands. A plain
  `docker-compose up` uses the official file directly and does not apply the
  localhost-only internal port policy.

## Dependency Setup

The environment setup step checks:

- Linux distribution and package manager
- CPU core count
- total memory
- free disk near the repository
- Docker and Docker Compose availability
- `curl`, `tar`, `zstd`, and `git`
- root or usable `sudo`, because the official initialization scripts set data
  directory ownership before containers start

When automatic dependency installation is enabled, the script installs `sudo`
where needed by the official initialization scripts and uses the local
system package manager:

- Debian/Ubuntu: `apt-get`
- Fedora/RHEL-style systems: `dnf` or `yum`
- Alpine: `apk`

If the package manager is unsupported, the script stops and tells the operator
to install Docker, Docker Compose, `curl`, `tar`, and `zstd` manually.

After installing Docker, a non-root user may need to log out and back in before
the new `docker` group membership takes effect. For the current shell session,
run the menu with `sudo` if Docker reports a daemon permission error.

## Source Repository Checks

For Docker deployment, this `fractal-indexer-deploy` repository is enough. The
official source repositories below are optional and only needed for code
research:

- `fractal-indexer`
- `stake-indexer`
- `fractal-proof-publisher`

The wizard can detect whether they exist next to this repository and optionally
clone or fast-forward them.

## Resource Configuration

The resource step controls Docker container memory limits only. It does not
change Fractald, host CPU affinity, disk layout, or node pruning.

Modes:

- `auto`: enter the percentage of currently available machine memory to allocate
  to indexer containers. The script splits that budget across ClickHouse, Pika,
  API, stake-indexer, PostgreSQL, and Redis, with the largest share reserved for
  the API because the official snapshot can need substantial memory while
  loading BRC20 balances.
- `manual`: enter each service memory limit in GB.

The generated override and runtime Compose files are local runtime files and are
ignored by git. The runtime copies preserve the official services/images while
applying the default localhost-only bindings for internal stores.

## Official Version Guardrails

The menu is intentionally official-version-only. It fetches service templates
from `fractal-bitcoin/fractal-indexer-deploy` at runtime and does not run
locally modified fractal-indexer, stake-indexer, or proof-publisher images. If
an official image and official deploy config are out of sync, the menu should
stop with a clear diagnostic instead of guessing protocol fields.

The validation step checks the active runtime Compose file, so edits to the
generated `docker-compose.menu.yaml` are validated too.

Known startup checks:

- The `fractal-indexer` `indexer` and `api` services must use the official
  `fractalbitcoin/fractal-indexer` image repository.
- The optional `proof-publisher` service must use the official
  `fractalbitcoin/fractal-proof-publisher` image repository.
- When proof-publisher dry-run startup is selected, the official image must be
  reachable in the registry or already cached locally with an official registry
  digest. This check runs before long-running deployment work.
- `fractalbitcoin/stake-indexer` must use an official pinned tag at `v0.1.1`
  or newer. `latest` is rejected because it makes reproducing protocol behavior
  harder for operators.
- The pinned official image must accept the checked-in
  `stake-indexer/conf/indexer/config.yaml`. If the image still behaves like an
  older release, the menu reports the upstream image/config mismatch and stops.
- If the official image accepts the current config but rejects fractional
  release tiers such as `37.5`, the menu reports the same upstream image/config
  mismatch instead of rounding reward rules.
- If a stale stake-indexer container is still calling `getblockindexrange`, the
  menu reports that the running service is older than the current official
  release and stops rather than applying local RPC fallback patches.
- The health check inspects recent stake-indexer logs as well as HTTP ports, so
  an API process that is up but repeatedly failing block sync is reported as a
  deployment problem.
- Container diagnostics compare Docker Compose labels with the current deploy
  directory. This catches accidental tests from another checkout using the same
  default Compose project name.
- Mutating Compose actions such as `up`, `down`, and snapshot restore refuse to
  continue when the matching containers belong to a different deploy directory.
- Starting `stake-indexer` directly from the menu still requires the official
  statehash readiness endpoint unless the explicit observation/debug bypass is
  enabled in the one-pass wizard.

## Expected Deployment Order

Use option `1` for the beginner path:

1. Select English or Chinese.
2. Let the script auto-detect Fractald.
3. Confirm the Fractald RPC password.
4. Review the plan.
5. Confirm once, then let the script run the deployment flow automatically.

Beginner mode applies these defaults:

- install missing dependencies: yes
- clone optional source repositories: no
- resource mode: `auto` with `70%` of currently available memory
- restore the official snapshot: yes
- move existing data automatically: no
- stop conflicting Compose services when needed: yes
- require statehash readiness before `stake-indexer`: yes
- proof-publisher: disabled

Use option `2` for the advanced one-pass path when you need to adjust RPC/ZMQ,
resources, snapshot behavior, or proof-publisher:

1. Enter Fractald RPC/ZMQ settings and RPC credentials.
2. Choose whether missing dependencies may be installed automatically.
3. Choose whether optional official source repositories should be cloned for
   research.
4. Choose automatic or manual Docker container memory limits.
5. Choose whether to restore the official snapshot.
6. Choose whether existing `fractal-indexer/data` may be moved to a timestamped
   backup if present.
7. Choose whether to prepare and optionally start `proof-publisher` in dry-run
   mode.
8. Review the plan.
9. Confirm once, then let the script run the deployment flow automatically.

The automatic flow is:

1. Run preflight checks.
2. Write `chain.yaml` for `fractal-indexer` and `stake-indexer`.
3. Validate Fractald RPC from inside a Docker container.
4. Verify `getblockhash`/`getblock` access at the snapshot and configured
   reward-start heights.
5. Reject pruned Fractald nodes whose `pruneheight` is above the snapshot
   height.
6. Generate local runtime Compose files that bind internal datastore ports to
   `127.0.0.1` by default.
7. Restore the `fractal-indexer` snapshot when enabled. If restore is disabled
   and no existing database files exist, require block height `0` and run the
   official from-genesis initialization command instead.
8. Start `fractal-indexer`; manual start from the menu refuses an empty,
   uninitialized data directory.
9. Wait until `http://127.0.0.1:8000/brc20/bestheight` is available.
10. Check the FIP-101 state hash at the configured `start_reward_height`,
   requiring a non-empty indexed `blockHash` and `stateHash`
   (`1760000` in the current official config).
11. Start `stake-indexer` only after the FIP-101 state hash is ready. The wizard
   has an explicit observation/debug option to continue without it.
12. Confirm `http://127.0.0.1:9637/indexer/status` returns data.
13. Write `proof-publisher/config.json` when enabled.
14. Start `proof-publisher` only if dry-run startup was selected.
15. Print final health checks, including internal datastore port exposure.

## Fractald Connectivity

For a complete checklist of required Fractald, wallet, port, and generated-file
settings, read [Configuration Requirements](CONFIGURATION.en.md).

The default prompts assume Fractald runs on the Docker host and is reachable from
containers through Compose `host-gateway` aliases:

```text
RPC:       http://fractald:8332
ZMQ block: tcp://fractald:10330
ZMQ tx:    tcp://fractald:10331
```

If Fractald uses custom ports or another machine, enter the URLs reachable from
inside the containers.

## Fractald Auto-Detection

The wizard tries to detect a local Fractald node before asking for RPC/ZMQ
settings. It checks:

- `FRACTALD_CONF` or `BITCOIN_CONF` environment variables
- running `fractald` or `bitcoind` process arguments such as `-conf=...`,
  `-datadir=...`, `-rpcport=...`, `-zmqpubhashblock=...`, and
  `-zmqpubrawtx=...`
- common config paths such as:
  - `/data/fractald-full/bitcoin.conf`
  - `/data/fractald/bitcoin.conf`
  - `/data/fractalbitcoin/bitcoin.conf`
  - `~/.fractalbitcoin/bitcoin.conf`
  - `~/.bitcoin/bitcoin.conf`

When a config file is found, the wizard reads `rpcuser`, `rpcpassword`,
`rpcport`, `rpcbind`, `rpcconnect`, `zmqpubhashblock`, `zmqpubrawblock`,
`zmqpubrawtx`, and `zmqpubhashtx`.

Detected `127.0.0.1`, `localhost`, and `0.0.0.0` hosts are converted to the
Compose host alias `fractald`, because the indexer containers access the node
through Docker `host-gateway`.

The detected RPC password is never printed directly. The final prompt still lets
the operator confirm or replace every detected value.

If the detected RPC or ZMQ bind address is loopback-only, the menu prints a
warning. In that case, Fractald may need to also listen on the Docker bridge or
`0.0.0.0`, with an appropriate `rpcallowip`, before containers can reach it.

During the automatic flow, the wizard runs a JSON-RPC `getblockchaininfo` check
from inside a Docker container. This catches wrong ports such as `10332` vs
`8332`, bad credentials, missing `rpcallowip`, and broken `host-gateway`
connectivity before large snapshot work begins.

The same gate also checks `getblockhash` and `getblock` for the snapshot height
and the official stake reward-start height when the local node is already synced
past those heights. This catches stale Fractald data, over-pruned nodes, or
unexpected RPC compatibility problems before `stake-indexer` is started.

If the node is pruned, the reported `pruneheight` must be less than or equal to
the snapshot height. Otherwise the node may be unable to serve the blocks needed
after the restored snapshot.

To run only this Fractald connectivity gate without starting any indexer
services:

```bash
bash scripts/deploy-menu.sh --validate-rpc
```

To check only whether `fractal-indexer` has produced a confirmed FIP-101 state
hash at the official reward-start height:

```bash
bash scripts/deploy-menu.sh --validate-statehash
```

The statehash readiness check does not accept an HTTP-success response whose
`blockHash` is empty. The API can return a provisional state hash for an
unindexed future height, which is not sufficient to start `stake-indexer`.

To check the default one-pass path without writing configs, restoring snapshots,
or starting services:

```bash
bash scripts/deploy-menu.sh --doctor
```

## Official Deploy Bundle

This repository does not vendor the official service directories. The menu uses
`.official/fractal-indexer-deploy` as a local checkout of the official
deployment repository.

Useful commands:

```bash
bash scripts/deploy-menu.sh --sync-official
bash scripts/deploy-menu.sh --official-status
```

Set `OFFICIAL_DEPLOY_UPDATE=never` to stop automatic fast-forward updates for a
single run, or set `OFFICIAL_DEPLOY_REF=<tag-or-commit>` to pin a specific
upstream version.

The readiness report chains preflight, container RPC validation, prune/snapshot
compatibility, the default snapshot disk guard, and default startup port
availability. It exits non-zero when the default path is blocked, for example
when free disk is below `SNAPSHOT_MIN_FREE_GB` or a default service port is
already in use.

For script maintenance, run the internal helper self-test:

```bash
bash scripts/deploy-menu.sh --self-test
```

This does not call Docker, write configs, restore snapshots, or contact
Fractald. It checks helper behavior such as version comparison, JSON number
parsing, address normalization, resource calculations, and reading the official
stake reward height.

## Snapshot URL Override

The default snapshot height is `1753260`.

```bash
SNAPSHOT_HEIGHT=1753260 bash scripts/deploy-menu.sh
```

Before restoring a snapshot, the menu checks free disk on the filesystem that
contains `fractal-indexer`. The default minimum is 400 GB:

```bash
SNAPSHOT_MIN_FREE_GB=400 bash scripts/deploy-menu.sh
```

To force the interface language without the startup selector:

```bash
DEPLOY_LANG=zh bash scripts/deploy-menu.sh
DEPLOY_LANG=en bash scripts/deploy-menu.sh
```

To point at a different compatible snapshot location:

```bash
SNAPSHOT_BASE_URL=https://example.com/fractal-indexer/1753260 bash scripts/deploy-menu.sh
```

The snapshot endpoint must expose these files:

- `pika-brc20.tar.zst`
- `brc20-base.tar.zst`
- `pika.tar.zst`
- `clickhouse.tar.zst`

## Manual Equivalent

The menu does not replace the underlying Compose layout. Every action maps back
to the same manual commands documented in the root README and each service
directory:

```bash
cd .official/fractal-indexer-deploy/fractal-indexer && bash ./scripts/init.sh && docker compose up -d
cd ../stake-indexer && bash ./scripts/init.sh && docker compose up -d
```

When the menu has generated `docker-compose.menu.yaml`, operate each affected
stack through the menu or include the generated files explicitly:

```bash
cd .official/fractal-indexer-deploy/fractal-indexer && docker-compose -f docker-compose.menu.yaml -f docker-compose.override.yaml up -d
cd ../stake-indexer && docker-compose -f docker-compose.menu.yaml -f docker-compose.override.yaml up -d
```

Using plain `docker-compose up -d` remains the official manual path, but it
bypasses the menu's localhost-only binding for internal datastore ports.
