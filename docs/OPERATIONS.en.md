# Operations Guide

## Recommended Flow

1. Confirm Fractald is synced or usable.
2. Confirm RPC and ZMQ are enabled.
3. Use [Configuration Requirements](CONFIGURATION.en.md) to confirm the
   container-visible RPC/ZMQ endpoints.
4. Start this menu through `scripts/run-menu-persistent.sh`.
5. Run option `15` or `--doctor` for a non-destructive readiness report.
6. Run option `1` for one-pass deployment.
7. Reattach with `tmux attach -t fractal-indexer-oneclick` if SSH disconnects.
8. Run `bash scripts/deploy-menu.sh --health`.

## Service Order

The menu starts services in this order:

1. Restore `fractal-indexer` snapshot.
2. Start `fractal-indexer`.
3. Wait for API and statehash readiness.
4. Start `stake-indexer`.
5. Optionally prepare/start `proof-publisher` in dry-run mode.

`stake-indexer` is intentionally blocked until statehash readiness is proven,
unless the user explicitly enables observation/debug mode.

## Logs

Persistent wrapper logs:

```bash
tail -f logs/deploy-menu-latest.log
```

Compose logs:

```bash
cd fractal-indexer
docker compose -f docker-compose.menu.yaml -f docker-compose.override.yaml logs --tail=100 -f
```

For older systems:

```bash
docker-compose -f docker-compose.menu.yaml -f docker-compose.override.yaml logs --tail=100 -f
```

## Updates

Pull the latest repository code, then run:

```bash
bash scripts/deploy-menu.sh --self-test
bash scripts/deploy-menu.sh --doctor
```

Do not delete runtime `data/` directories unless you intend to rebuild or
restore from snapshot again.
