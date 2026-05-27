# FAQ

## 这个项目会安装 Fractald 吗？

不会。第一版只部署索引服务栈。Fractald 的安装、同步、剪枝、磁盘规划是单独工作。

## 这里用的是魔改 stake-indexer 吗？

不是。菜单会校验官方 Docker 镜像仓库，并拒绝本地魔改 Fractal 服务镜像。

## 为什么要用 tmux？

快照恢复和追块可能很久。如果直接在 SSH 里跑，连接断开后 shell 可能结束，导致后续服务没有启动。
`scripts/run-menu-persistent.sh` 会把菜单放进不死会话里运行。

## 如果快照恢复后 SSH 断了怎么办？

先恢复会话：

```bash
tmux attach -t fractal-indexer-oneclick
```

如果菜单进程已经结束，先检查：

```bash
bash scripts/deploy-menu.sh --health
```

如果 `fractal-indexer` 没跑但数据已经存在，用菜单选项 `7`。如果 statehash 已就绪但
`stake-indexer` 没跑，用菜单选项 `8`。

## proof-publisher 会真的广播交易吗？

默认不会。生成配置时使用 `dry_run=true` 和 `disable_broadcast=true`。真实广播必须单独复核，并准备真实操作者凭证。

## 剪枝 Fractald 节点能用吗？

可以，但前提是节点仍能提供官方快照之后所需区块。菜单会检查 `pruneheight` 和必要区块访问。

## API 可以公网开放吗？

只有你明确做好保护时才建议开放。内部数据库端口默认 localhost-only，但公开 API 端口沿用上游 Compose 行为，请用防火墙或反向代理限制访问。
