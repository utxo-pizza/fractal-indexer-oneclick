# FAQ

For longer operator answers backed by a runnable diagnosis/remediation helper,
see [Operator Q&A And Script Helper](QA.en.md).

## Does this install Fractald?

No. This first package only deploys the indexer stack. Fractald installation,
syncing, pruning, and disk layout are separate work.

## Is this using modified staking code?

No. The menu validates official Docker image repositories and refuses local
modified Fractal service images.

## Why use tmux?

Snapshot restore and catch-up can take a long time. If you run the menu directly
inside SSH and the connection drops, the shell can stop before the next service
starts. `scripts/run-menu-persistent.sh` keeps the deployment menu inside a
persistent session.

## What happens if SSH disconnects after the snapshot is restored?

Reattach with:

```bash
tmux attach -t fractal-indexer-oneclick
```

If the menu process already ended, run:

```bash
bash scripts/deploy-menu.sh --health
```

If `fractal-indexer` is not running but data exists, use menu option `8`. If
statehash is ready and `stake-indexer` is not running, use option `9`.

## Does proof-publisher broadcast transactions?

Not by default. The generated config uses `dry_run=true` and
`disable_broadcast=true`. Real broadcasting requires separate review and real
operator credentials.

## Should this add one-click operator registration later?

Yes, but it must be a separate explicit flow, not part of the default deploy.
The current menu prepares config and dry-run validation, and it reserves a
one-click operator registration entry that safely refuses execution today. After
the official registration rules, portal behavior, and transaction fields are
stable, real registration can be wired into that entry. Before broadcasting, it
must show the transaction, fee, inscription payload, owner/change/reward
addresses, and require a second confirmation.

## Can I run this on a pruned Fractald node?

Yes, only if the node can still serve the blocks required after the official
snapshot. The menu checks `pruneheight` and required block access before startup.

## Can I expose the API publicly?

Only if you deliberately protect it. Internal datastore ports are localhost-only
by default, but public API ports follow upstream Compose behavior. Use firewall
or reverse proxy rules.

## How do I quickly check whether Fractald RPC is exposed?

Run:

```bash
DEPLOY_LANG=en bash scripts/qa-helper.sh --check rpc-exposure
```

If you see `0.0.0.0:*` or `[::]:*`, verify firewall rules before continuing.
The helper-supported remediation path is in
[Operator Q&A And Script Helper](QA.en.md).
