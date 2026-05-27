# 配置需求说明

这份文档说明一键菜单真正需要哪些外部配置。项目只部署官方
`fractal-indexer`、`stake-indexer` 和可选 dry-run `proof-publisher`；它不安装、
不同步 Fractald 节点。

官方部署模板不会复制进本仓库。脚本运行时会把官方
`fractal-bitcoin/fractal-indexer-deploy` 拉取到
`.official/fractal-indexer-deploy`，然后在这个目录里生成本地配置。

## 1. 服务器和系统

最低建议：

- Linux x86_64 服务器。
- Docker 和 Docker Compose。菜单可以在常见发行版上自动安装缺失依赖。
- `git`、`curl`、`tar`、`zstd`。
- 推荐 `tmux` 或 `screen`，避免 SSH 断开中断长时间任务。
- 索引服务栈建议至少 64 GB 内存，128 GB 更稳。
- 索引服务栈建议至少 500 GB 可用 SSD/NVMe 空间；如果 Fractald 也在同机，
  还要另外给节点数据留空间。

菜单的资源自动配置只限制 Docker 容器内存，不会修改 Fractald、CPU affinity、
磁盘分区或节点剪枝策略。

## 2. Fractald 节点要求

必须已有一个可用 Fractald 节点。菜单会从 Docker 容器网络里验证它，而不是只在
宿主机上验证。

必须满足：

- Fractald 已同步到官方快照高度之后。当前快照高度是 `1753260`。
- `getblockchaininfo` 可用。
- `getblockhash` 和 `getblock` 能读取快照高度和 stake 奖励起点附近区块。
- 如果是剪枝节点，`pruneheight` 必须小于或等于 `1753260`。
- RPC 用户名和密码必须存在，且密码应足够随机。
- RPC 和 ZMQ 必须能被 Docker 容器访问。

默认容器内地址：

```text
RPC:       http://fractald:8332
ZMQ block: tcp://fractald:10330
ZMQ tx:    tcp://fractald:10331
```

`fractald` 是 Docker `host-gateway` 别名。它不是公网域名。

如果 Fractald 只监听 `127.0.0.1`，容器通常访问不到。需要让 Fractald 监听 Docker
bridge 或宿主机内网地址，并用防火墙保护，避免 RPC 暴露公网。

示例 `bitcoin.conf` 片段：

```ini
server=1
rpcuser=bitcoinrpc
rpcpassword=REPLACE_WITH_LONG_RANDOM_PASSWORD
rpcport=8332
rpcbind=0.0.0.0
rpcallowip=127.0.0.1
rpcallowip=172.16.0.0/12
zmqpubrawblock=tcp://0.0.0.0:10330
zmqpubrawtx=tcp://0.0.0.0:10331
```

这个示例只说明容器可访问配置。生产环境必须用防火墙限制 RPC/ZMQ 入站来源。

## 3. 菜单会让你填写什么

菜单 `1` 是推荐的一条路流程。

环境和资源：

- 是否自动安装缺失依赖。
- 是否克隆官方源码仓库用于研究。Docker 部署不需要源码。
- 资源模式：自动按当前可用内存分配，或手动填写容器内存限制。

Fractald 连接：

- 容器内可访问的 Fractald RPC URL。
- 容器内可访问的 ZMQ block URL。
- 容器内可访问的 ZMQ tx URL。
- RPC 用户名。
- RPC 密码。

快照和启动：

- 是否恢复官方 `fractal-indexer` 快照。普通部署建议选择是。
- 是否备份现有 `fractal-indexer/data`。
- 是否停止当前旧容器，避免 Compose 冲突。
- 等待超时时间。
- 是否允许 `stake-indexer` 在 statehash 未就绪时启动。普通部署不要开启；
  这只适合观察或调试。

可选 proof-publisher dry-run：

- proof-publisher 使用的 Fractald RPC URL、用户名、密码。
- indexer owner 私钥 WIF。
- 找零地址。
- 奖励地址。
- indexer name。
- 已有 `indexer_id`。注册前可留空，已有注册结果时再填写真实值。
- UniSat Open API key。

当前一键菜单强制写入：

```json
"dry_run": true,
"disable_broadcast": true
```

所以它只用于配置准备和健康检查，不会真实注册、签名或广播。

## 4. 自动生成的本地文件

菜单会生成这些本地运行时文件，它们都不应该提交到 Git：

- `.official/fractal-indexer-deploy/fractal-indexer/conf/indexer/chain.yaml`
- `.official/fractal-indexer-deploy/stake-indexer/conf/indexer/chain.yaml`
- `.official/fractal-indexer-deploy/proof-publisher/config.json`
- `.official/fractal-indexer-deploy/fractal-indexer/docker-compose.override.yaml`
- `.official/fractal-indexer-deploy/stake-indexer/docker-compose.override.yaml`
- `.official/fractal-indexer-deploy/fractal-indexer/docker-compose.menu.yaml`
- `.official/fractal-indexer-deploy/stake-indexer/docker-compose.menu.yaml`
- `data/`
- `logs/`

生成的配置文件可能包含 RPC 密码、私钥或 API key。不要贴到公开 issue、聊天记录或
日志里。

## 5. 端口

本项目默认涉及这些端口：

```text
8000  fractal-indexer API
9637  stake-indexer API
8080  proof-publisher API，可选
9222  fractal-indexer 内部 pika-brc20
9432  stake-indexer 内部 PostgreSQL
9379  stake-indexer 内部 Redis
```

菜单会尽量把内部数据库端口限制到 `127.0.0.1`。API 端口是否公开取决于你的防火墙
和反向代理策略。

Fractald 的 `8332`、`10330`、`10331` 由你的节点负责，不由本项目创建。

## 6. 不建议手动改的内容

普通部署不要手动改：

- 官方 Docker 镜像名。
- `stake-indexer/conf/indexer/config.yaml` 里的高度和奖励规则。
- `fractal-indexer` 快照高度，除非官方发布新的兼容快照。
- `runtime.dry_run=false` 或 `disable_broadcast=false`。

如果官方规则变化，应该更新本仓库后重新跑 `--doctor` 和 `--self-test`。

如果只想更新官方部署模板：

```bash
bash scripts/deploy-menu.sh --sync-official
```

如果需要固定到某个官方 tag、branch 或 commit：

```bash
OFFICIAL_DEPLOY_REF=<tag-or-commit> bash scripts/deploy-menu.sh --sync-official
```

## 7. 部署前检查

先跑：

```bash
bash scripts/deploy-menu.sh --doctor
```

只检查 Fractald RPC/ZMQ 和快照兼容：

```bash
bash scripts/deploy-menu.sh --validate-rpc
```

部署后检查：

```bash
bash scripts/deploy-menu.sh --health
```
