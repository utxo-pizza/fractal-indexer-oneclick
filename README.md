# Fractal Indexer One-Click

[中文说明](README.zh-CN.md)

Fractal Indexer One-Click is a guided deployment package for operators who
already have a working Fractald node and want to deploy the official
`fractal-indexer`, `stake-indexer`, and optional dry-run `proof-publisher`
stack with fewer manual steps.

This first version deliberately does **not** install or sync Fractald. Treat the
node as a separate prerequisite. Official deployment directories are fetched at
runtime into `.official/fractal-indexer-deploy`; this repository keeps only the
one-click scripts and documentation.

## What It Deploys

- Official `fractalbitcoin/fractal-indexer` Docker image and data services.
- Official `fractalbitcoin/stake-indexer:v0.1.1` Docker image.
- Optional official `fractalbitcoin/fractal-proof-publisher` dry-run config.
- Runtime fetch/update of the official `fractal-bitcoin/fractal-indexer-deploy`
  repository.
- Official Fractal indexer snapshot restore at height `1753260`.
- Safety checks for RPC/ZMQ, pruned-node compatibility, statehash readiness,
  Docker Compose ownership, official image repositories, and local-only
  internal datastore ports.

It does not deploy custom commission logic, modified staking rules, or local
patched service images.

## Requirements

See [Configuration Requirements](docs/CONFIGURATION.en.md) for the full field
reference. If you want to judge how beginner-friendly the flow is, start with
the [beginner difficulty guide](docs/BEGINNER.en.md).

- Linux server with an already synced or usable Fractald node.
- Fractald RPC reachable from Docker containers.
- Fractald ZMQ block and transaction endpoints.
- Docker and Docker Compose. The menu can install missing runtime dependencies
  on common Linux distributions.
- Recommended: `tmux` or `screen`, so the long snapshot restore keeps running
  after SSH disconnects.
- Recommended hardware for the indexer stack: 64 GB RAM minimum, 128 GB RAM
  preferred, and at least 500 GB free SSD/NVMe space. More disk is safer for
  growth and logs.

If your Fractald node is pruned, its `pruneheight` must be at or below the
snapshot height used by this package.

## Quick Start

Install `git` and `tmux` if needed, then clone the repository:

```bash
git clone https://github.com/utxo-pizza/fractal-indexer-oneclick.git
cd fractal-indexer-oneclick
```

Start the guided menu inside a persistent terminal session:

```bash
bash scripts/run-menu-persistent.sh
```

Choose language, then use menu option `1`:

```text
1) Beginner mode: diagnose Fractald, then deploy with safe defaults
```

Beginner mode diagnoses Fractald automatically, installs missing dependencies by
default, uses `auto 70%` resource limits, restores the official snapshot, waits
for the FIP-101 statehash prerequisite, and keeps proof-publisher disabled. When
detection succeeds, it usually asks only for RPC password confirmation and final
deployment approval.

Use menu option `2` for the advanced one-pass wizard when you need full control.

## Reattach After SSH Disconnect

The wrapper uses `tmux` first, then `screen`, then `nohup` as a fallback.

For the default `tmux` session:

```bash
tmux attach -t fractal-indexer-oneclick
```

View logs:

```bash
ls -lah logs/
tail -f logs/deploy-menu-latest.log
```

If you already know what you are doing, you can still run the menu directly:

```bash
bash scripts/deploy-menu.sh
```

For public tutorials, prefer the persistent wrapper.

## Useful Commands

```bash
# Non-destructive readiness report
bash scripts/deploy-menu.sh --doctor

# Start beginner mode directly
bash scripts/deploy-menu.sh --beginner

# Validate Fractald RPC from inside Docker networking
bash scripts/deploy-menu.sh --validate-rpc

# Check whether fractal-indexer has the stake statehash prerequisite
bash scripts/deploy-menu.sh --validate-statehash

# Sync the official fractal-indexer-deploy bundle
bash scripts/deploy-menu.sh --sync-official

# Show current official deployment bundle version
bash scripts/deploy-menu.sh --official-status

# Full service health check
bash scripts/deploy-menu.sh --health

# Validate proof-publisher dry-run config
bash scripts/deploy-menu.sh --validate-proof

# Show the future operator registration checklist without broadcasting
bash scripts/deploy-menu.sh --proof-registration-checklist

# Internal script self-test for maintainers
bash scripts/deploy-menu.sh --self-test
```

## Documentation

- [English quick start](docs/QUICKSTART.en.md)
- [Chinese quick start](docs/QUICKSTART.zh-CN.md)
- [Beginner difficulty guide](docs/BEGINNER.en.md)
- [小白使用难度说明](docs/BEGINNER.zh-CN.md)
- [Configuration requirements](docs/CONFIGURATION.en.md)
- [中文配置需求说明](docs/CONFIGURATION.zh-CN.md)
- [Official deployment bundle updates](docs/OFFICIAL-UPDATES.en.md)
- [官方部署包更新策略](docs/OFFICIAL-UPDATES.zh-CN.md)
- [Operations guide](docs/OPERATIONS.en.md)
- [中文运维指南](docs/OPERATIONS.zh-CN.md)
- [Troubleshooting](docs/TROUBLESHOOTING.en.md)
- [中文故障排查](docs/TROUBLESHOOTING.zh-CN.md)
- [FAQ](docs/FAQ.en.md)
- [中文 FAQ](docs/FAQ.zh-CN.md)
- [Publishing checklist](docs/PUBLISHING.en.md)
- [中文发布清单](docs/PUBLISHING.zh-CN.md)
- [Repository setup](docs/REPOSITORY-SETUP.en.md)
- [中文仓库发布设置](docs/REPOSITORY-SETUP.zh-CN.md)
- [Project scope](docs/PROJECT-SCOPE.md)
- [Full interactive menu reference](docs/interactive-cli.md)

## Security Notes

- Do not expose Fractald RPC to the public Internet.
- Use a strong random RPC password.
- Internal datastore host ports are bound to `127.0.0.1` by default.
- The proof publisher is generated with `dry_run=true` and
  `disable_broadcast=true`; real broadcasting needs a separate manual review.
- Before official third-party operator registration opens, this project only
  prepares registration config and dry-run validation. A future one-click
  registration flow must still show the transaction, fee, inscription payload,
  and require a second confirmation.
- The menu and `--register-operator` reserve the one-click registration entry;
  today it safely refuses execution and does not sign or broadcast.
- Never paste private keys or API keys into public issues.

## Status

This is the first open-source packaging version for the indexer stack only. The
Fractald node installer is intentionally out of scope for now.
