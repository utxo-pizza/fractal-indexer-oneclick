# Troubleshooting

## SSH Disconnected

Reconnect and attach:

```bash
tmux attach -t fractal-indexer-oneclick
```

If the deployment menu is no longer running, check service state:

```bash
bash scripts/deploy-menu.sh --health
```

If the snapshot finished but the automatic flow stopped before service startup,
use the menu to continue:

- option `8`: initialize and start `fractal-indexer`
- option `9`: initialize and start `stake-indexer`

## Fractald RPC Fails

Run:

```bash
bash scripts/deploy-menu.sh --validate-rpc
```

Common causes:

- wrong RPC port, for example `10332` vs `8332`
- wrong RPC user or password
- Fractald only listening on localhost while Docker cannot reach it
- missing `rpcallowip` for Docker bridge access
- pruned node cannot serve the required snapshot or reward-start block

## Statehash Is Not Ready

Run:

```bash
bash scripts/deploy-menu.sh --validate-statehash
```

`stake-indexer` should not be started for normal operation until this passes.
Wait for `fractal-indexer` to catch up past the configured reward start height.

## Health Reports Historical Restart

A historical container restart is a warning when the container is currently
running and not OOM-killed. Investigate logs if the restart count keeps growing.

## Disk Space

The snapshot restore needs a large amount of free space. The default guard is:

```bash
SNAPSHOT_MIN_FREE_GB=400
```

Use a larger filesystem for production. Lower the guard only after confirming
the expected final size.
