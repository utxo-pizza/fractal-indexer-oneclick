# 运维指南

## 推荐流程

1. 确认 Fractald 已同步或可用。
2. 确认 RPC 和 ZMQ 已启用。
3. 对照 [配置需求说明](CONFIGURATION.zh-CN.md) 确认容器内可访问的 RPC/ZMQ 地址。
4. 运行 `bash scripts/deploy-menu.sh --sync-official` 拉取或更新官方部署包。
5. 用 `scripts/run-menu-persistent.sh` 启动菜单。
6. 先跑菜单 `15` 或 `--doctor` 做非破坏性诊断。
7. 跑菜单 `1` 一条路部署。
8. 如果 SSH 断开，用 `tmux attach -t fractal-indexer-oneclick` 恢复。
9. 跑 `bash scripts/deploy-menu.sh --health` 检查服务。

## 服务启动顺序

菜单按这个顺序启动：

1. 恢复 `fractal-indexer` 官方快照。
2. 启动 `fractal-indexer`。
3. 等待 API 和 statehash 就绪。
4. 启动 `stake-indexer`。
5. 可选准备/启动 dry-run 模式 `proof-publisher`。

默认情况下，`stake-indexer` 会等 statehash 通过才启动。只有用户明确开启观察/调试模式时，才会跳过这个保护。

## 日志

不死进程包装脚本日志：

```bash
tail -f logs/deploy-menu-latest.log
```

Compose 日志：

```bash
cd .official/fractal-indexer-deploy/fractal-indexer
docker compose -f docker-compose.menu.yaml -f docker-compose.override.yaml logs --tail=100 -f
```

旧系统可能需要：

```bash
docker-compose -f docker-compose.menu.yaml -f docker-compose.override.yaml logs --tail=100 -f
```

## 更新

拉取最新代码后运行：

```bash
bash scripts/deploy-menu.sh --self-test
bash scripts/deploy-menu.sh --doctor
```

不要随便删除运行时 `data/` 目录，除非你明确准备重新恢复快照或重建数据。
