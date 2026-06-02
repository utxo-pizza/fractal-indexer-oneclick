# Official Deployment Bundle Updates

This repository only maintains the one-click scripts, documentation, and safety
checks. Official service directories are no longer vendored into this
repository.

At runtime, the menu uses:

```text
.official/fractal-indexer-deploy
```

as the local checkout of the official
`fractal-bitcoin/fractal-indexer-deploy` repository.

## Default Behavior

Default environment:

```bash
OFFICIAL_DEPLOY_REPO=https://github.com/fractal-bitcoin/fractal-indexer-deploy.git
OFFICIAL_DEPLOY_UPDATE=auto
DEPLOY_BUNDLE_DIR=.official/fractal-indexer-deploy
```

The first run clones the official deployment repository automatically. Later
runs use `git fetch` plus `git pull --ff-only`, accepting fast-forward updates
only. Without `OFFICIAL_DEPLOY_REF`, the script follows the official default
branch. If an earlier pinned commit left `.official/fractal-indexer-deploy` in a
detached HEAD state, the next automatic update switches back to the official
default branch before pulling.

If the official repository updates Compose files, configuration templates, or
the proof-publisher directory, the next local run pulls those changes.

The script also writes generated runtime paths to the official checkout's
`.git/info/exclude`, including `chain.yaml`, `docker-compose.*.yaml`,
`config.json`, `data/`, and `logs/`, so local runtime files do not look like
changes to official code.

## Useful Commands

Show the current official deployment checkout:

```bash
bash scripts/deploy-menu.sh --official-status
```

Validate current official image and config alignment:

```bash
bash scripts/deploy-menu.sh --validate-official
```

Manually sync the official deployment bundle:

```bash
bash scripts/deploy-menu.sh --sync-official
```

Temporarily disable automatic updates:

```bash
OFFICIAL_DEPLOY_UPDATE=never bash scripts/deploy-menu.sh
```

Pin a specific official tag, branch, or commit:

```bash
OFFICIAL_DEPLOY_REF=<tag-or-commit> bash scripts/deploy-menu.sh --sync-official
```

## Why Official Directories Are Not Vendored

- Avoid stale templates when upstream changes.
- Avoid accidentally turning official service templates into local patched
  versions.
- Keep this repository focused on deployment workflow instead of protocol or
  service forks.

This open-source repository should only commit:

- `scripts/` one-click menu and validation scripts.
- `docs/`, README files, and GitHub templates.
- Project metadata such as `LICENSE`, `NOTICE.md`, and `.gitignore`.

It should not commit:

- Vendored copies of the official `fractal-indexer/`, `stake-indexer/`, or
  `proof-publisher/` service directories.
- The runtime `.official/` directory.
- Snapshot data, database data, RPC passwords, wallet private keys, or API keys.

## After An Official Update

Official updates still pass through the menu guardrails:

- Docker images must use official `fractalbitcoin/*` repositories.
- `stake-indexer` must not downgrade to an incompatible version.
- Fractald RPC/ZMQ and prune height are validated.
- Local Compose overrides and `chain.yaml` files are generated at runtime
  instead of being committed to the official checkout.

If an upstream update breaks validation, do not bypass the guardrail. Pin the
last known good commit until this repository is adapted.

Most users only need `--sync-official`. Updating this one-click repository is
needed only when upstream changes directory layout, Compose service names,
configuration fields, or proof-publisher rules in a way that breaks the menu
checks.
