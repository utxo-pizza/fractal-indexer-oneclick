# Publishing Checklist

Use this before pushing the repository to GitHub.

## Repository Settings

- Choose a clear repository name, for example `fractal-indexer-oneclick`.
- Add the description: `One-click official Fractal indexer stack deployment for existing Fractald nodes`.
- Add topics: `fractal-bitcoin`, `indexer`, `staking`, `docker-compose`, `ops`.
- Enable issues and discussions if you want community support.

## Before First Push

```bash
bash -n scripts/*.sh
bash scripts/deploy-menu.sh --self-test
git status --short
```

Confirm no runtime files are present:

- `fractal-indexer/data/`
- `stake-indexer/data/`
- `proof-publisher/config.json`
- `chain.yaml`
- private keys
- RPC passwords
- API keys

## First Push

```bash
git add .
git commit -m "Initial standalone Fractal indexer one-click package"
git branch -M main
git remote add origin https://github.com/utxo-pizza/fractal-indexer-oneclick.git
git push -u origin main
```

## Release Notes Template

```text
First standalone release.

- Deploys official fractal-indexer and stake-indexer for existing Fractald nodes.
- Adds bilingual one-pass menu documentation.
- Adds persistent tmux/screen/nohup launcher.
- Keeps proof-publisher dry-run by default.
- Does not install Fractald.
- Does not include dynamic commission logic.
```
