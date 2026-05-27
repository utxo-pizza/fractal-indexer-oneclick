# 快速开始

本指南适用于服务器上已经有可用 Fractald 节点的情况。

开始前请先读一遍 [配置需求说明](CONFIGURATION.zh-CN.md)。如果 Fractald 的
RPC/ZMQ 没有被 Docker 容器访问到，后续快照和索引器启动都会失败。
如果你是第一次部署，建议先看 [小白使用难度说明](BEGINNER.zh-CN.md)，确认哪些会
自动完成、哪些必须自己准备。

## 1. 准备不死终端

先安装 `tmux`：

```bash
sudo apt-get update
sudo apt-get install -y git tmux
```

其他 Linux 发行版可以使用自己的包管理器。后续部署菜单也可以补常见依赖。

## 2. 克隆项目

```bash
git clone https://github.com/utxo-pizza/fractal-indexer-oneclick.git
cd fractal-indexer-oneclick
```

首次运行菜单会自动拉取官方 `fractal-bitcoin/fractal-indexer-deploy` 到
`.official/fractal-indexer-deploy`。更多说明见
[官方部署包更新策略](OFFICIAL-UPDATES.zh-CN.md)。

## 3. 启动菜单

```bash
bash scripts/run-menu-persistent.sh
```

如果 SSH 断开：

```bash
tmux attach -t fractal-indexer-oneclick
```

## 4. 使用极简小白模式

选择语言，然后选择 `1`。

这个模式会自动诊断 Fractald，然后使用安全默认值：

- 自动安装缺失依赖：是。
- 克隆源码研究：否。
- 资源配置：`auto 70%`。
- 恢复官方快照：是。
- 停止冲突服务：是。
- `stake-indexer` 必须等待 statehash：是。
- proof-publisher：否。

如果 Fractald 自动识别成功，通常只需要确认：

- RPC 密码。
- 最终部署计划。

需要手动调整 RPC/ZMQ、资源、快照或 proof-publisher 时，选择菜单 `2` 使用高级一条路
部署。

不确定某一项怎么填时，先运行：

```bash
bash scripts/deploy-menu.sh --doctor
```

它不会写配置、恢复快照或启动服务，只做环境和 Fractald 可用性诊断。

## 5. 验证

```bash
bash scripts/deploy-menu.sh --health
```

核心成功标准：

- `fractal-indexer` API 在 `http://127.0.0.1:8000` 可访问。
- 配置的奖励起点高度 statehash 可用。
- `stake-indexer` API 在 `http://127.0.0.1:9637` 可访问。
- 内部数据库端口仅绑定 localhost。

如果没有显式准备并启动 proof-publisher，它可以保持未运行。
