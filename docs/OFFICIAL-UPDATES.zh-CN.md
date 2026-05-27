# 官方部署包更新策略

本仓库只维护一键脚本、文档和安全检查。官方服务目录不再复制进仓库。

运行菜单时，脚本会使用：

```text
.official/fractal-indexer-deploy
```

作为官方 `fractal-bitcoin/fractal-indexer-deploy` 的本地工作目录。

## 默认行为

默认环境变量：

```bash
OFFICIAL_DEPLOY_REPO=https://github.com/fractal-bitcoin/fractal-indexer-deploy.git
OFFICIAL_DEPLOY_UPDATE=auto
DEPLOY_BUNDLE_DIR=.official/fractal-indexer-deploy
```

首次运行会自动 `git clone` 官方部署仓库。之后运行菜单或检查命令时，会尝试
`git fetch` + `git pull --ff-only`，只接受快进更新。没有设置
`OFFICIAL_DEPLOY_REF` 时，脚本跟随官方仓库默认分支；如果之前固定过 commit 导致
`.official/fractal-indexer-deploy` 处于 detached HEAD，下一次自动更新会先切回官方
默认分支再快进。

如果官方仓库更新了 Compose、配置模板或 proof-publisher 目录，本地下一次运行会拉到
最新版本。

脚本会在官方 checkout 的 `.git/info/exclude` 里忽略本地生成的 `chain.yaml`、
`docker-compose.*.yaml`、`config.json`、`data/` 和 `logs/`，避免这些运行时文件被误
认为是要提交的官方代码改动。

## 常用命令

查看当前官方部署包状态：

```bash
bash scripts/deploy-menu.sh --official-status
```

手动同步官方部署包：

```bash
bash scripts/deploy-menu.sh --sync-official
```

临时关闭自动更新：

```bash
OFFICIAL_DEPLOY_UPDATE=never bash scripts/deploy-menu.sh
```

固定到官方某个 tag、branch 或 commit：

```bash
OFFICIAL_DEPLOY_REF=<tag-or-commit> bash scripts/deploy-menu.sh --sync-official
```

## 为什么不把官方目录放进本仓库

- 避免官方更新后本仓库模板过期。
- 避免误把官方服务模板改成社区魔改版本。
- 让本仓库职责保持清楚：只做部署工作流，不 fork 协议和服务实现。

所以这个开源仓库应该只提交：

- `scripts/` 一键菜单和检查脚本。
- `docs/`、README、GitHub 模板等说明文件。
- 必要的项目元数据，例如 `LICENSE`、`NOTICE.md`、`.gitignore`。

不应该提交：

- 官方 `fractal-indexer/`、`stake-indexer/`、`proof-publisher/` 服务目录副本。
- `.official/` 运行时目录。
- 快照数据、数据库数据、RPC 密码、钱包私钥、API key。

## 更新后的注意事项

官方更新后仍然会经过本菜单的保护：

- 校验 Docker 镜像仓库必须是官方 `fractalbitcoin/*`。
- 校验 `stake-indexer` 版本不能退回不兼容版本。
- 校验 Fractald RPC/ZMQ 和剪枝高度。
- 生成本地 Compose override 和 chain.yaml，而不是修改官方仓库提交。

如果官方部署包更新导致检查失败，先不要绕过保护。可以固定到上一个可用 commit，
等本仓库适配后再升级。

一般用户只需要运行 `--sync-official`。只有官方更新改变了目录结构、Compose 服务名、
配置字段或 proof-publisher 规则，导致本菜单检查失败时，才需要更新这个一键脚本仓库。
