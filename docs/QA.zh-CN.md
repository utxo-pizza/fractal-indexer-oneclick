# 运营商 Q&A 与脚本助手

这份 Q&A 不只给答案，也对应一个可执行入口：

```bash
# 交互式选择问题
bash scripts/qa-helper.sh

# 一次做常见只读检查
DEPLOY_LANG=zh bash scripts/qa-helper.sh --check-all

# 查看全部可处理的问题
DEPLOY_LANG=zh bash scripts/qa-helper.sh --list
```

规则很简单：

- `--check <topic>` 只检查，不修改机器。
- `--fix <topic>` 给出处理路径。
- 只有文中明确写出的 `--fix <topic> --apply` 才会执行动作。
- 网络、防火墙、缺失区块这类可能影响业务的事情，助手宁可停下并给准确步骤，也不
  会偷偷修改。

## 问题目录

| 问题 | Topic | 脚本能做什么 |
| --- | --- | --- |
| 缺少 Docker / Compose / 工具 | `prerequisites` | 检查；显式确认后安装支持的依赖 |
| 官方部署包是不是最新 | `official` | 查看版本；显式确认后更新 |
| 本机是否有 Fractald | `fractald` | 检查进程和常见配置路径 |
| RPC 不通、端口错、剪枝不兼容 | `rpc` | 从 Docker 网络调用官方校验 |
| `Method not found` / 旧 RPC 方法日志 | `health` | 从日志诊断旧官方服务镜像 |
| RPC/ZMQ 是否暴露公网 | `rpc-exposure` | 扫描监听；可选应用宿主机 UFW 保护 |
| API/数据库端口是否暴露 | `api-exposure` | 扫描监听并给 Docker-aware 处理方案 |
| 快照和剪枝高度是否满足 | `snapshot` | 校验必要历史块 |
| 磁盘/内存够不够 | `resources` | 检查保护线并给迁移建议 |
| SSH 中断后怎么恢复 | `interrupted` | 给恢复路径；可重新打开菜单 |
| 为什么 stake 没启动 | `statehash` | 校验 statehash 门槛 |
| 服务现在正常吗 | `health` | 调用完整健康检查 |
| proof 是否可能广播 | `proof` | 检查；可强制恢复 dry-run |
| 能不能一键注册运营商 | `registration` | 显示官方开放前的边界 |
| 有没有敏感文件误提交 | `secrets` | 检查被 Git 跟踪的高风险文件 |
| 这里是不是魔改版本 | `scope` | 明确官方-only 范围 |
| 提 issue 应该提供什么 | `issue-report` | 可生成不读取密钥的初步报告 |

## Q：这是从空服务器开始的一键安装吗？

不是。项目部署官方索引栈，不安装或同步 Fractald。

脚本检查：

```bash
DEPLOY_LANG=zh bash scripts/qa-helper.sh --check fractald
DEPLOY_LANG=zh bash scripts/qa-helper.sh --check prerequisites
```

如果没有节点，助手会明确提示先准备 Fractald；它不会伪装成能够补齐节点历史数据。

## Q：缺少 Docker、Compose、curl、zstd 怎么办？

脚本先检查，再由你明确同意安装：

```bash
DEPLOY_LANG=zh bash scripts/qa-helper.sh --check prerequisites
DEPLOY_LANG=zh bash scripts/qa-helper.sh --fix prerequisites --apply
```

`--apply` 会调用部署菜单支持的依赖安装流程，可能需要 `sudo`。安装完成后仍建议重新
登录或使用 `sudo` 运行当前会话，避免 Docker group 权限尚未生效。

## Q：项目是不是一直使用官方版本？官方更新后怎么办？

本项目不 vendoring 官方服务目录；运行时使用官方
`fractal-bitcoin/fractal-indexer-deploy` checkout，并校验官方镜像来源。

```bash
DEPLOY_LANG=zh bash scripts/qa-helper.sh --check scope
DEPLOY_LANG=zh bash scripts/qa-helper.sh --check official
DEPLOY_LANG=zh bash scripts/qa-helper.sh --fix official --apply
```

最后一条会显式更新官方部署包，不会加入动态佣金或本地质押魔改。

## Q：RPC 端口到底是 `8332` 还是 `10332`？

用节点实际监听的端口，不要按旧文档猜。

```bash
DEPLOY_LANG=zh bash scripts/qa-helper.sh --check rpc
```

助手会走与部署相同的 Docker 网络 RPC 校验，能暴露错误端口、错误认证、Docker
不可达和剪枝缺块问题。需要指定自定义配置路径时：

```bash
FRACTALD_CONF=/path/to/bitcoin.conf DEPLOY_LANG=zh \
  bash scripts/qa-helper.sh --check rpc
```

## Q：风险 - 日志里有 `getblockindexrange` 或 `Method not found` 怎么办？

不要通过开放更多 RPC、暴露 Fractald 公网端口、或运行本地魔改镜像来掩盖这个问题。
助手会从官方 `stake-indexer` 日志里识别旧服务/旧镜像症状：

```bash
DEPLOY_LANG=zh bash scripts/qa-helper.sh --check health
DEPLOY_LANG=zh bash scripts/qa-helper.sh --check official
DEPLOY_LANG=zh bash scripts/qa-helper.sh --fix official --apply
```

如果健康检查提示旧 `stake-indexer` 仍在调用 `getblockindexrange`，应更新官方部署包/
镜像，并通过菜单重建官方服务。这个仓库不能为了绕过该问题去补丁 Fractald 或运行本地
魔改 stake 镜像。

## Q：风险 - Fractald RPC/ZMQ 有没有暴露到公网？

这是最重要的安全风险之一。RPC 密码不能替代私有监听和防火墙。

```bash
DEPLOY_LANG=zh bash scripts/qa-helper.sh --check rpc-exposure
DEPLOY_LANG=zh bash scripts/qa-helper.sh --fix rpc-exposure
```

检查发现 `0.0.0.0` 或 `[::]` 监听时，修复预览会给出只绑定 localhost 和 Docker
bridge 的 `bitcoin.conf` 形态。

如果 Fractald 直接运行在宿主机、已经启用 `ufw`，并且你确认 Docker 容器需要访问的
网段，可让助手应用保护端口的规则：

```bash
docker network inspect bridge --format '{{(index .IPAM.Config 0).Subnet}}'
QA_DOCKER_CIDR=172.17.0.0/16 DEPLOY_LANG=zh \
  bash scripts/qa-helper.sh --fix rpc-exposure --apply
```

请把 `172.17.0.0/16` 替换成你主机上确认过的容器网段。助手会把规则插入到旧的宽松
放行规则之前，然后打印 `ufw` 状态供你复核。

如果 Fractald 端口由 Docker 发布，助手会拒绝自动套 UFW 规则，因为需要
Docker-aware 防火墙或改成私有端口绑定。

## Q：风险 - indexer API 和数据库端口能公开吗？

`9222`、`9432`、`9379` 是内部数据服务，不应公网开放。`8000`、`9637`、可选
`8080` 只有在你明确需要公网服务并加了访问保护时才应开放。

```bash
DEPLOY_LANG=zh bash scripts/qa-helper.sh --check api-exposure
DEPLOY_LANG=zh bash scripts/qa-helper.sh --fix api-exposure
```

这些服务通过 Docker 发布端口，助手会给出反向代理白名单或
`DOCKER-USER`/`nftables` 方向，但不会盲目执行一条可能让容器互联或公网策略失效的
防火墙命令。通过本项目菜单启动服务，会继续保护内部数据库端口为 localhost-only。

## Q：剪枝节点能用吗？为什么一定要官方快照？

可以使用剪枝节点，但必须保留官方快照和奖励起点所需的区块。当前关键边界是：

```text
pruneheight <= 1753260
```

```bash
DEPLOY_LANG=zh bash scripts/qa-helper.sh --check snapshot
DEPLOY_LANG=zh bash scripts/qa-helper.sh --fix snapshot
```

如果节点已经剪掉必要区块，助手不能“修复”不存在的历史数据，会要求你换更少剪枝的
节点或全节点。官方快照用于保持 `fractal-indexer` 状态与当前 proof/statehash 规则
兼容。

## Q：磁盘和内存到底够不够？

```bash
DEPLOY_LANG=zh bash scripts/qa-helper.sh --check resources
DEPLOY_LANG=zh bash scripts/qa-helper.sh --fix resources
```

助手会检查快照默认保护线（默认 `400 GB` 可用空间）和当前可用内存。空间不足时，
正确处理是把部署目录放到更大 SSD/NVMe 文件系统或释放空间，不是直接绕过保护线。

## Q：SSH 断了，或者快照好了但服务没接着启动怎么办？

```bash
DEPLOY_LANG=zh bash scripts/qa-helper.sh --check interrupted
DEPLOY_LANG=zh bash scripts/qa-helper.sh --fix interrupted --apply
```

脚本会提示 `tmux` 恢复方式和主菜单续跑顺序；带 `--apply` 会重新打开交互菜单，由你
根据已完成的阶段选择启动步骤，不会重新下载快照或擅自覆盖数据。

## Q：为什么 `stake-indexer` 没启动？是不是坏了？

普通部署要求 `fractal-indexer` 先产生官方配置奖励起点的有效 statehash。没通过就
不会启动 stake，这是保护，不是故障。

```bash
DEPLOY_LANG=zh bash scripts/qa-helper.sh --check statehash
DEPLOY_LANG=zh bash scripts/qa-helper.sh --fix statehash
```

修复动作会告诉你保持 `fractal-indexer` 运行并等待追平；不会绕过 statehash 关卡。

## Q：服务已经部署了，怎么判断现在正常不正常？

```bash
DEPLOY_LANG=zh bash scripts/qa-helper.sh --check health
DEPLOY_LANG=zh bash scripts/qa-helper.sh --fix health
```

健康检查覆盖容器状态、OOM/退出、内部端口、`fractal-indexer` API、statehash、
`stake-indexer` 状态和奖励同步状态。若需查看日志或只重启受影响服务，修复路径会
引导你回到主菜单操作。

## Q：proof-publisher 会不会偷偷签名或广播？

默认不会。官方准备流程必须保持：

```json
"dry_run": true,
"disable_broadcast": true
```

```bash
DEPLOY_LANG=zh bash scripts/qa-helper.sh --check proof
DEPLOY_LANG=zh bash scripts/qa-helper.sh --fix proof --apply
```

如果配置被误改成可广播，`--apply` 会先以受限权限备份原配置，再把两个安全开关恢复
为 `true` 并重新校验。备份同样可能包含密钥，不能公开。

## Q：官方开启第三方服务商注册后，能一键注册吗？

当前不能真实注册或广播；这是有意的边界。

```bash
DEPLOY_LANG=zh bash scripts/qa-helper.sh --check registration
DEPLOY_LANG=zh bash scripts/qa-helper.sh --fix registration
```

助手会列出未来正式注册必须完成的复核清单，不会绕过官方未明确的规则。

## Q：可以在这个仓库加入动态佣金或质押魔改吗？

这个开源一键部署仓库保持官方-only，不加入动态佣金和自定义质押逻辑。

```bash
DEPLOY_LANG=zh bash scripts/qa-helper.sh --check scope
```

研究或实验代码应该与官方部署项目隔离，避免普通用户部署到不兼容规则。

## Q：怎么避免把 RPC 密码、私钥、API key 发到 GitHub？

```bash
DEPLOY_LANG=zh bash scripts/qa-helper.sh --check secrets
DEPLOY_LANG=zh bash scripts/qa-helper.sh --fix secrets
```

助手会检查 Git 是否跟踪常见运行时配置、数据或日志路径。若密钥已经公开推送，必须
立即轮换；在后续 commit 删除文件并不能让泄露的密钥重新安全。

## Q：提 issue 时应该提供哪些信息？

可以先生成一个不读取 RPC 密码、钱包私钥和生成配置内容的初步报告：

```bash
DEPLOY_LANG=zh bash scripts/qa-helper.sh --fix issue-report --apply
```

报告仍可能包含路径或网络监听信息，公开贴出前还要自行检查脱敏。遇到新问题时，可以
先用对应 topic 检查，再把脱敏结果提到 issue；后续高频问题会继续收进本 Q&A 和
助手脚本。
