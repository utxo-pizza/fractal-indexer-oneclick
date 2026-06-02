# Fractal Indexer One-Click

[English README](README.md)

这是一个面向索引服务商/运维人员的一键部署项目。它假设你已经有可用的
Fractald 节点，然后用交互式菜单部署官方 `fractal-indexer`、
`stake-indexer`，以及可选的 dry-run `proof-publisher`。

第一版明确不安装、不配置、不同步 Fractald 节点。节点部署是单独项目。
官方部署目录会在运行时自动拉取到 `.official/fractal-indexer-deploy`，本仓库只保留
一键脚本和文档。

## 它会部署什么

- 官方 `fractalbitcoin/fractal-indexer` Docker 镜像和数据服务。
- 当前部署包固定的官方 `fractalbitcoin/stake-indexer:v0.2.0` Docker 镜像。
- 可选官方 `fractalbitcoin/fractal-proof-publisher` dry-run 配置。
- 运行时自动拉取/更新官方 `fractal-bitcoin/fractal-indexer-deploy`。
- 官方 `fractal-indexer` 高度 `1753260` 快照恢复。
- RPC/ZMQ、剪枝节点兼容、statehash、Docker Compose 归属、官方镜像仓库、
  内部数据库端口 localhost-only 等安全检查。

它不包含动态佣金魔改、不修改质押规则、不构建本地魔改镜像。

## 前置条件

完整填写说明见 [配置需求说明](docs/CONFIGURATION.zh-CN.md)。
如果你想先判断这个项目对小白是否友好，先看
[小白使用难度说明](docs/BEGINNER.zh-CN.md)。

- Linux 服务器。
- 已经同步好或可用的 Fractald 节点。
- Fractald RPC 能被 Docker 容器访问。
- Fractald ZMQ block/tx 端点可用。
- Docker 和 Docker Compose。菜单可以在常见 Linux 发行版上自动补依赖。
- 推荐安装 `tmux` 或 `screen`，避免 SSH 断开导致快照恢复被中断。
- 推荐配置：内存最低 64 GB，建议 128 GB；SSD/NVMe 至少空闲 500 GB，
  后续增长建议留更多空间。

如果 Fractald 是剪枝节点，`pruneheight` 必须小于或等于本项目使用的快照高度。

## 快速开始

先安装 `git` 和 `tmux`，然后克隆项目：

```bash
git clone https://github.com/utxo-pizza/fractal-indexer-oneclick.git
cd fractal-indexer-oneclick
```

用“不死进程”包装脚本启动菜单：

```bash
bash scripts/run-menu-persistent.sh
```

选择语言后，使用菜单 `1`：

```text
1) 极简小白模式：自动诊断 Fractald，默认部署
```

极简模式会自动诊断 Fractald，默认自动安装依赖、使用 `auto 70%` 资源配置、恢复
官方快照、等待 FIP-101 所需 statehash 就绪，并默认不启动 proof-publisher。识别
成功时，它通常只需要你确认 RPC 密码和最终部署计划。

需要完整自定义时，使用菜单 `2` 高级一条路部署。

## SSH 断开后如何恢复

包装脚本优先使用 `tmux`，其次 `screen`，最后才用 `nohup`。

默认 `tmux` 会话恢复方式：

```bash
tmux attach -t fractal-indexer-oneclick
```

查看日志：

```bash
ls -lah logs/
tail -f logs/deploy-menu-latest.log
```

熟手也可以直接运行菜单：

```bash
bash scripts/deploy-menu.sh
```

但给小白教程时，建议统一使用 `scripts/run-menu-persistent.sh`。

## 常用命令

```bash
# 非破坏性一条路部署诊断
bash scripts/deploy-menu.sh --doctor

# 交互式 Q&A 检查/处理助手
bash scripts/qa-helper.sh

# 一次运行常见只读 Q&A 检查
DEPLOY_LANG=zh bash scripts/qa-helper.sh --check-all

# 直接启动极简小白模式
bash scripts/deploy-menu.sh --beginner

# 从 Docker 网络内验证 Fractald RPC
bash scripts/deploy-menu.sh --validate-rpc

# 检查 stake-indexer 所需 statehash 是否就绪
bash scripts/deploy-menu.sh --validate-statehash

# 同步官方 fractal-indexer-deploy 部署包
bash scripts/deploy-menu.sh --sync-official

# 查看当前官方部署包版本
bash scripts/deploy-menu.sh --official-status

# 校验官方镜像和配置是否一致
bash scripts/deploy-menu.sh --validate-official

# 完整服务健康检查
bash scripts/deploy-menu.sh --health

# 校验 proof-publisher dry-run 配置
bash scripts/deploy-menu.sh --validate-proof

# 查看未来运营商注册前置清单，不广播
bash scripts/deploy-menu.sh --proof-registration-checklist

# 维护者自测
bash scripts/deploy-menu.sh --self-test
```

## 文档

- [中文快速开始](docs/QUICKSTART.zh-CN.md)
- [English quick start](docs/QUICKSTART.en.md)
- [小白使用难度说明](docs/BEGINNER.zh-CN.md)
- [Beginner difficulty guide](docs/BEGINNER.en.md)
- [中文配置需求说明](docs/CONFIGURATION.zh-CN.md)
- [Configuration requirements](docs/CONFIGURATION.en.md)
- [官方部署包更新策略](docs/OFFICIAL-UPDATES.zh-CN.md)
- [Official deployment bundle updates](docs/OFFICIAL-UPDATES.en.md)
- [中文运维指南](docs/OPERATIONS.zh-CN.md)
- [Operations guide](docs/OPERATIONS.en.md)
- [中文故障排查](docs/TROUBLESHOOTING.zh-CN.md)
- [Troubleshooting](docs/TROUBLESHOOTING.en.md)
- [中文 FAQ](docs/FAQ.zh-CN.md)
- [FAQ](docs/FAQ.en.md)
- [运营商 Q&A](docs/QA.zh-CN.md)
- [Operator Q&A](docs/QA.en.md)
- [中文发布清单](docs/PUBLISHING.zh-CN.md)
- [Publishing checklist](docs/PUBLISHING.en.md)
- [中文仓库发布设置](docs/REPOSITORY-SETUP.zh-CN.md)
- [Repository setup](docs/REPOSITORY-SETUP.en.md)
- [项目范围](docs/PROJECT-SCOPE.md)
- [完整交互菜单说明](docs/interactive-cli.md)

## 安全提醒

- 不要把 Fractald RPC 暴露到公网。
- RPC 密码必须随机且足够长。
- 内部数据库端口默认只绑定 `127.0.0.1`。
- 用 `sudo ss -lntp | grep -E ':(8332|10332|10330|10331)\b' || true`
  检查 Fractald RPC/ZMQ 监听情况。
- 用 `DEPLOY_LANG=zh bash scripts/qa-helper.sh --check rpc-exposure` 检查；
  支持的处理动作见 [运营商 Q&A 与脚本助手](docs/QA.zh-CN.md)。
- 用 `DEPLOY_LANG=zh bash scripts/qa-helper.sh --check api-exposure`
  检查 API/数据库端口暴露。
- 用 `DEPLOY_LANG=zh bash scripts/qa-helper.sh --check secrets`
  检查是否误跟踪敏感配置。
- `proof-publisher` 默认生成 `dry_run=true` 和 `disable_broadcast=true`；
  真实广播必须单独人工复核。
- 第三方运营商注册开放前，本项目只做注册配置准备和 dry-run 校验；未来加入
  一键注册时也必须先展示交易、费用、铭文内容，并要求二次确认。
- 菜单和 `--register-operator` 已预留一键注册入口；当前会安全拒绝执行，不会
  签名或广播。
- 不要在公开 issue 里粘贴私钥、RPC 密码或 API key。

## 当前状态

这是第一版“只部署索引服务栈”的开源打包项目。Fractald 节点安装器暂不包含在内。
