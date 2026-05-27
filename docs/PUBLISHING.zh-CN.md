# 发布清单

推送到 GitHub 前按这个清单检查。

## 仓库设置

- 仓库名建议：`fractal-indexer-oneclick`。
- 描述建议：`One-click official Fractal indexer stack deployment for existing Fractald nodes`。
- Topics 建议：`fractal-bitcoin`、`indexer`、`staking`、`docker-compose`、`ops`。
- 如果要社区反馈，开启 issues 和 discussions。

## 首次推送前

```bash
bash -n scripts/*.sh
bash scripts/deploy-menu.sh --self-test
git status --short
```

确认不要包含运行时文件：

- `fractal-indexer/data/`
- `stake-indexer/data/`
- `proof-publisher/config.json`
- `chain.yaml`
- 私钥
- RPC 密码
- API key

## 首次推送

```bash
git add .
git commit -m "Initial standalone Fractal indexer one-click package"
git branch -M main
git remote add origin https://github.com/utxo-pizza/fractal-indexer-oneclick.git
git push -u origin main
```

## Release Notes 模板

```text
First standalone release.

- Deploys official fractal-indexer and stake-indexer for existing Fractald nodes.
- Adds bilingual one-pass menu documentation.
- Adds persistent tmux/screen/nohup launcher.
- Keeps proof-publisher dry-run by default.
- Does not install Fractald.
- Does not include dynamic commission logic.
```
