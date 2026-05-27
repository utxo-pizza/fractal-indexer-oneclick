# Quick Start

Use this guide when Fractald is already installed and reachable on the server.

Before starting, read [Configuration Requirements](CONFIGURATION.en.md). If
Fractald RPC/ZMQ is not reachable from Docker containers, snapshot restore and
indexer startup will fail later.
If this is your first deployment, read the
[beginner difficulty guide](BEGINNER.en.md) first so you know what is automated
and what you still need to prepare.

## 1. Prepare a Persistent Shell

Install `tmux` first:

```bash
sudo apt-get update
sudo apt-get install -y git tmux
```

Other Linux distributions can use their own package manager. The deployment
menu can also install common missing dependencies later.

## 2. Clone

```bash
git clone https://github.com/utxo-pizza/fractal-indexer-oneclick.git
cd fractal-indexer-oneclick
```

The first menu run automatically fetches the official
`fractal-bitcoin/fractal-indexer-deploy` repository into
`.official/fractal-indexer-deploy`. See
[Official Deployment Bundle Updates](OFFICIAL-UPDATES.en.md) for details.

## 3. Start The Menu

```bash
bash scripts/run-menu-persistent.sh
```

If SSH disconnects:

```bash
tmux attach -t fractal-indexer-oneclick
```

## 4. Use Beginner Mode

Choose language, then choose option `1`.

This mode diagnoses Fractald automatically, then uses safe defaults:

- Install missing dependencies: yes.
- Clone source repositories for research: no.
- Resource mode: `auto 70%`.
- Restore official snapshot: yes.
- Stop conflicting services: yes.
- Require statehash before starting `stake-indexer`: yes.
- proof-publisher: no.

If Fractald is detected successfully, you usually only confirm:

- RPC password.
- Final deployment plan.

Use menu option `2` for the advanced one-pass wizard when you need to adjust
RPC/ZMQ, resources, snapshot behavior, or proof-publisher.

If you are unsure about any value, run:

```bash
bash scripts/deploy-menu.sh --doctor
```

It does not write configs, restore snapshots, or start services. It only checks
environment readiness and Fractald reachability.

## 5. Verify

```bash
bash scripts/deploy-menu.sh --health
```

The core success path is:

- `fractal-indexer` API responds on `http://127.0.0.1:8000`.
- Statehash at the configured reward start height is available.
- `stake-indexer` API responds on `http://127.0.0.1:9637`.
- Internal datastore ports are localhost-only.

Proof publisher can remain absent unless you explicitly prepared and started it.
