# 小白使用难度说明

这份说明只回答一个问题：如果你不是专业运维，这个一键脚本到底难不难。

## 结论

如果服务器上已经有一个可用的 Fractald 节点，并且 RPC/ZMQ 能被 Docker 容器访问，
这个脚本属于比较简单的半自动部署。菜单 `1` 是极简小白模式，会尽量把交互压缩到
“确认 RPC 密码 + 确认部署计划”。

如果你还没有 Fractald 节点，或者不知道 RPC/ZMQ 是什么，这个项目还不是完全从零
无脑部署。Fractald 节点安装、同步和开放 RPC/ZMQ 是前置条件，不包含在本仓库第一版
范围内。

可以这样理解：

```text
已有可用 Fractald：简单，主要是确认默认值
Fractald 配置不标准：中等，需要检查 RPC/ZMQ
完全从零服务器：不适合直接上手，先准备节点
```

## 大部分会自动做什么

菜单会自动处理这些事情：

- 拉取官方 `fractal-bitcoin/fractal-indexer-deploy` 部署包。
- 检查或安装常见依赖，例如 Docker、Docker Compose、curl、tar、zstd、git。
- 尝试识别本机 Fractald 配置文件和运行参数。
- 生成 `fractal-indexer` 和 `stake-indexer` 使用的 `chain.yaml`。
- 按当前可用内存自动生成 Docker 容器内存限制。
- 恢复官方 `fractal-indexer` 快照。
- 启动 `fractal-indexer`。
- 等待 FIP-101 所需 statehash 就绪。
- 启动 `stake-indexer`。
- 做部署后健康检查。
- 默认把内部数据库端口限制到 `127.0.0.1`。

## 小白通常只需要确认什么

如果 Fractald 在本机，并且配置标准，菜单 `1` 会自动使用这些默认值：

- 自动安装依赖：是。
- 克隆源码研究：否。
- 资源配置：`auto 70%`。
- 恢复官方快照：是。
- 自动停止冲突服务：是。
- `stake-indexer` 必须等待 statehash：是。
- proof-publisher：否。

识别成功时，你通常只需要确认：

- Fractald RPC 密码。
- 最终部署计划。

如果自动识别失败，才需要切到菜单 `2` 高级一条路部署，并手动确认：

- Fractald RPC URL，通常是 `http://fractald:8332`。
- Fractald ZMQ block URL，通常是 `tcp://fractald:10330`。
- Fractald ZMQ tx URL，通常是 `tcp://fractald:10331`。
- Fractald RPC 用户名。

## 哪些地方最容易卡住

最常见的问题不是索引器本身，而是 Fractald 前置条件：

- Fractald 没同步到快照高度之后。
- Fractald RPC 只监听 `127.0.0.1`，Docker 容器访问不到。
- RPC 端口填错。当前常见配置是 `8332`，不是所有文档里的默认端口都适合你的节点。
- ZMQ 没开启，或者端口不是 `10330` / `10331`。
- 剪枝节点的 `pruneheight` 已经高于官方快照高度 `1753260`。
- 服务器磁盘不够，快照恢复会失败。

不确定时，先运行：

```bash
bash scripts/deploy-menu.sh --doctor
```

它不会恢复快照、不会写正式配置、不会启动服务，只做部署前诊断。

## 最简单的推荐路径

```bash
git clone https://github.com/utxo-pizza/fractal-indexer-oneclick.git
cd fractal-indexer-oneclick
bash scripts/run-menu-persistent.sh
```

然后：

1. 选择中文。
2. 选择菜单 `1`。
3. 脚本自动诊断 Fractald。
4. 确认 RPC 密码。
5. 看部署计划，确认后开始。

## 它还不是完全无脑的原因

这个项目当前只负责部署官方索引服务栈，不负责安装或同步 Fractald。

所以真正需要用户提前知道的是：

- 我的 Fractald 在哪里。
- RPC 用户名和密码是什么。
- RPC/ZMQ 是否能让 Docker 容器访问。
- 服务器磁盘和内存是否足够。

只要这几项准备好了，后面的部署步骤大部分是自动化的。
