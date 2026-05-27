# 故障排查

## SSH 断开了

重新连接后恢复：

```bash
tmux attach -t fractal-indexer-oneclick
```

如果菜单进程已经不在，先看服务状态：

```bash
bash scripts/deploy-menu.sh --health
```

如果快照已经完成，但自动流程在启动服务前中断，可以用菜单继续：

- 选项 `8`：初始化并启动 `fractal-indexer`
- 选项 `9`：初始化并启动 `stake-indexer`

## Fractald RPC 不通

运行：

```bash
bash scripts/deploy-menu.sh --validate-rpc
```

常见原因：

- RPC 端口填错，例如 `10332` 和 `8332` 混淆。
- RPC 用户名或密码错误。
- Fractald 只监听 localhost，Docker 容器无法访问。
- 缺少允许 Docker bridge 访问的 `rpcallowip`。
- 剪枝节点无法提供快照高度或奖励起点高度所需区块。

如果你为了让 Docker 访问而调整了 Fractald 监听地址，要确认它没有暴露到公网：

```bash
DEPLOY_LANG=zh bash scripts/qa-helper.sh --check rpc-exposure
```

公网暴露检查和助手支持的处理动作见 [运营商 Q&A 与脚本助手](QA.zh-CN.md)。

## Statehash 没好

运行：

```bash
bash scripts/deploy-menu.sh --validate-statehash
```

正常部署不要在这里通过前启动 `stake-indexer`。等待 `fractal-indexer`
追过配置的奖励起点高度。

## Health 提示历史重启

如果容器当前运行、没有 OOM，历史 restart 只是警告。只有 restart 计数持续增长时，才需要进一步查日志。

## 磁盘空间

快照恢复需要大量空闲空间，默认保护线：

```bash
SNAPSHOT_MIN_FREE_GB=400
```

生产环境建议使用更大的文件系统。只有确认最终大小后，才降低这个保护线。
