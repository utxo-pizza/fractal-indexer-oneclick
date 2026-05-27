# Fractal Indexer One-Click

[English README](README.md)

这是一个面向索引服务商/运维人员的一键部署项目。它假设你已经有可用的
Fractald 节点，然后用交互式菜单部署官方 `fractal-indexer`、
`stake-indexer`，以及可选的 dry-run `proof-publisher`。

第一版明确不安装、不配置、不同步 Fractald 节点。节点部署是单独项目。

## 它会部署什么

- 官方 `fractalbitcoin/fractal-indexer` Docker 镜像和数据服务。
- 官方 `fractalbitcoin/stake-indexer:v0.1.1` Docker 镜像。
- 可选官方 `fractalbitcoin/fractal-proof-publisher` dry-run 配置。
- 官方 `fractal-indexer` 高度 `1753260` 快照恢复。
- RPC/ZMQ、剪枝节点兼容、statehash、Docker Compose 归属、官方镜像仓库、
  内部数据库端口 localhost-only 等安全检查。

它不包含动态佣金魔改、不修改质押规则、不构建本地魔改镜像。

## 前置条件

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
git clone https://github.com/YOUR_ORG/fractal-indexer-oneclick.git
cd fractal-indexer-oneclick
```

用“不死进程”包装脚本启动菜单：

```bash
bash scripts/run-menu-persistent.sh
```

选择语言后，使用菜单 `1`：

```text
1) 一条路自动部署：一次填完配置，然后自动部署
```

向导会一次性收集配置，展示部署计划，恢复官方快照，启动
`fractal-indexer`，等待 FIP-101 所需 statehash 就绪，然后启动
`stake-indexer`。

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

# 从 Docker 网络内验证 Fractald RPC
bash scripts/deploy-menu.sh --validate-rpc

# 检查 stake-indexer 所需 statehash 是否就绪
bash scripts/deploy-menu.sh --validate-statehash

# 完整服务健康检查
bash scripts/deploy-menu.sh --health

# 维护者自测
bash scripts/deploy-menu.sh --self-test
```

## 文档

- [中文快速开始](docs/QUICKSTART.zh-CN.md)
- [English quick start](docs/QUICKSTART.en.md)
- [中文运维指南](docs/OPERATIONS.zh-CN.md)
- [Operations guide](docs/OPERATIONS.en.md)
- [中文故障排查](docs/TROUBLESHOOTING.zh-CN.md)
- [Troubleshooting](docs/TROUBLESHOOTING.en.md)
- [中文 FAQ](docs/FAQ.zh-CN.md)
- [FAQ](docs/FAQ.en.md)
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
- `proof-publisher` 默认生成 `dry_run=true` 和 `disable_broadcast=true`；
  真实广播必须单独人工复核。
- 不要在公开 issue 里粘贴私钥、RPC 密码或 API key。

## 当前状态

这是第一版“只部署索引服务栈”的开源打包项目。Fractald 节点安装器暂不包含在内。
