# Quick Start

Use this guide when Fractald is already installed and reachable on the server.

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
git clone https://github.com/EY-hungry/fractal-indexer-oneclick.git
cd fractal-indexer-oneclick
```

## 3. Start The Menu

```bash
bash scripts/run-menu-persistent.sh
```

If SSH disconnects:

```bash
tmux attach -t fractal-indexer-oneclick
```

## 4. Use One-Pass Deployment

Choose language, then choose option `1`.

You will be asked for:

- Fractald RPC URL visible from containers, usually `http://fractald:8332`.
- Fractald ZMQ block URL, usually `tcp://fractald:10330`.
- Fractald ZMQ transaction URL, usually `tcp://fractald:10331`.
- RPC user and password.
- Whether to restore the official snapshot.
- Whether to prepare optional proof-publisher dry-run config.

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
