# Operator Q&A And Script Helper

This Q&A is backed by an executable entry point:

```bash
# Interactive problem selector
bash scripts/qa-helper.sh

# Run common read-only checks
DEPLOY_LANG=en bash scripts/qa-helper.sh --check-all

# List supported problem topics
DEPLOY_LANG=en bash scripts/qa-helper.sh --list
```

Rules:

- `--check <topic>` diagnoses without modifying the machine.
- `--fix <topic>` shows the remediation path.
- Only a documented `--fix <topic> --apply` action executes changes.
- For network policy, firewall decisions, or unavailable block history, the
  helper stops and gives an explicit path rather than making unsafe guesses.

## Topic Index

| Question | Topic | What the helper does |
| --- | --- | --- |
| Missing Docker / Compose / tools | `prerequisites` | Checks; installs supported dependencies after explicit approval |
| Is the official deployment bundle current | `official` | Shows version; updates after explicit approval |
| Is Fractald present on this host | `fractald` | Checks process and usual config paths |
| RPC, port, or pruning compatibility errors | `rpc` | Runs the container-network RPC validator |
| `Method not found` / old RPC method logs | `health` | Diagnoses stale official service images from logs |
| Public RPC/ZMQ exposure | `rpc-exposure` | Scans listeners; optionally applies host UFW protection |
| Public API/datastore exposure | `api-exposure` | Scans listeners and explains Docker-aware remediation |
| Snapshot and prune-height eligibility | `snapshot` | Validates required historical blocks |
| Disk/memory suitability | `resources` | Checks safety threshold and provides migration guidance |
| SSH disconnect or interrupted flow | `interrupted` | Gives recovery path; can reopen the menu |
| Why stake did not start | `statehash` | Checks the statehash startup gate |
| Are deployed services healthy | `health` | Runs the complete health check |
| What changed in stake-indexer v0.2.0 | `official` / `health` | Checks official bundle/image/config alignment |
| Can proof-publisher broadcast | `proof` | Checks; can restore dry-run safeguards |
| Can operator registration run now | `registration` | Shows the pre-launch boundary |
| Did secrets enter git | `secrets` | Checks tracked high-risk runtime paths |
| Is this modified code | `scope` | States official-only scope |
| What should be attached to an issue | `issue-report` | Generates a first-line report without reading secrets |

## Q: Is this a from-empty-server installer?

No. It deploys the official indexer stack; it does not install or sync
Fractald.

```bash
DEPLOY_LANG=en bash scripts/qa-helper.sh --check fractald
DEPLOY_LANG=en bash scripts/qa-helper.sh --check prerequisites
```

If the node is absent, the helper asks you to prepare Fractald first. It does
not pretend it can recreate missing node history.

## Q: What if Docker, Compose, curl, or zstd is missing?

Check first, then explicitly approve supported dependency installation:

```bash
DEPLOY_LANG=en bash scripts/qa-helper.sh --check prerequisites
DEPLOY_LANG=en bash scripts/qa-helper.sh --fix prerequisites --apply
```

The apply action may need `sudo`. After Docker group membership changes, log in
again or run through `sudo` for the current session.

## Q: Does this keep using official versions? How do updates work?

The project does not vendor official service directories. At runtime it uses
the official `fractal-bitcoin/fractal-indexer-deploy` checkout and validates
official image sources.

As of the official deploy commit `fbc1466`, the current pinned stake image is
`fractalbitcoin/stake-indexer:v0.2.0`.

```bash
DEPLOY_LANG=en bash scripts/qa-helper.sh --check scope
DEPLOY_LANG=en bash scripts/qa-helper.sh --check official
DEPLOY_LANG=en bash scripts/qa-helper.sh --fix official --apply
```

The last command explicitly updates the official deployment bundle. It does not
introduce dynamic commission or local staking modifications.

## Q: What changed in the official `stake-indexer` v0.2.0 update?

The deploy bundle now pins `fractalbitcoin/stake-indexer:v0.2.0` and adds the
official Stage 2 config fields:

```yaml
pending_reward_lag_blocks: 1000
delay_submit_stage2_step_blocks: 100
delay_submit_stage2_step_percent: 10
commission_activation_blocks: 20160
stage2_start_height: 1824480
enable_mempool_indexing: false
start_reward_height: 1764000
```

The helper validates that these fields exist before startup:

```bash
DEPLOY_LANG=en bash scripts/qa-helper.sh --check official
DEPLOY_LANG=en bash scripts/deploy-menu.sh --validate-official
DEPLOY_LANG=en bash scripts/deploy-menu.sh --official-status
```

Do not edit reward phase, pending reward, or commission activation settings in
this one-click package. They are official protocol behavior.

## Q: How long does a commission change take to affect rewards now?

The v0.2.0 config includes:

```yaml
commission_activation_blocks: 20160
```

A valid `commission_rate` event is indexed, but the new ratio is delayed by the
official activation window before reward allocation uses it. Registration-time
commission ratios above the current official limit are rejected by
`stake-indexer`; do not patch this deployment package to bypass those rules.

## Q: Should RPC use `8332` or `10332`?

Use the port your node actually listens on rather than copying an older example.

```bash
DEPLOY_LANG=en bash scripts/qa-helper.sh --check rpc
```

The helper runs the same Docker-network validation as deployment and exposes
wrong ports, wrong authentication, Docker reachability, or pruned-block
problems. For a custom config path:

```bash
FRACTALD_CONF=/path/to/bitcoin.conf DEPLOY_LANG=en \
  bash scripts/qa-helper.sh --check rpc
```

## Q: Risk - logs mention `getblockindexrange` or `Method not found`.

Do not fix this by exposing more RPC methods or opening Fractald to the public
Internet. The helper checks for stale service/image symptoms in official
`stake-indexer` logs:

```bash
DEPLOY_LANG=en bash scripts/qa-helper.sh --check health
DEPLOY_LANG=en bash scripts/qa-helper.sh --check official
DEPLOY_LANG=en bash scripts/qa-helper.sh --fix official --apply
```

If the health check reports an old `stake-indexer` calling `getblockindexrange`,
update the official deployment bundle/image and recreate the official v0.2.0
service from the menu. This repository must not patch Fractald or run a local
modified stake image to hide that mismatch.

## Q: Risk - is Fractald RPC/ZMQ exposed publicly?

This is a critical operator risk. Password strength does not replace private
binding and firewall policy.

```bash
DEPLOY_LANG=en bash scripts/qa-helper.sh --check rpc-exposure
DEPLOY_LANG=en bash scripts/qa-helper.sh --fix rpc-exposure
```

When a listener is on `0.0.0.0` or `[::]`, the remediation preview shows a
`bitcoin.conf` shape restricted to localhost and the Docker bridge.

For host-run Fractald with active `ufw`, after confirming the container access
CIDR, the helper can apply protective port rules:

```bash
docker network inspect bridge --format '{{(index .IPAM.Config 0).Subnet}}'
QA_DOCKER_CIDR=172.17.0.0/16 DEPLOY_LANG=en \
  bash scripts/qa-helper.sh --fix rpc-exposure --apply
```

Replace `172.17.0.0/16` with the confirmed subnet for your host. The helper
inserts rules before older broad allow rules, then prints `ufw` status for
review.

If Docker publishes a Fractald port, the helper refuses automatic UFW
remediation because Docker-aware firewall rules or private port bindings are
required.

## Q: Risk - may indexer APIs and datastore ports be public?

`9222`, `9432`, and `9379` are internal data services and must not be public.
Ports `8000`, `9637`, and optional `8080` should be public only under an
intentional access policy.

```bash
DEPLOY_LANG=en bash scripts/qa-helper.sh --check api-exposure
DEPLOY_LANG=en bash scripts/qa-helper.sh --fix api-exposure
```

Those services are Docker-published ports. The helper explains reverse-proxy
allowlists or reviewed `DOCKER-USER`/`nftables` policies rather than running a
blind firewall mutation that might break required container traffic. Starting
services through this project continues to localize internal datastore ports.

## Q: Can a pruned node be used, and why restore the official snapshot?

A pruned node is usable only while it retains blocks required by the official
snapshot and reward-start processing. The current boundary is:

```text
pruneheight <= 1753260
```

```bash
DEPLOY_LANG=en bash scripts/qa-helper.sh --check snapshot
DEPLOY_LANG=en bash scripts/qa-helper.sh --fix snapshot
```

When required blocks have already been pruned, the helper cannot manufacture
history; it tells you to switch to a less-pruned or full node. The official
snapshot keeps `fractal-indexer` state compatible with current proof/statehash
rules.

## Q: Is there enough disk and memory?

```bash
DEPLOY_LANG=en bash scripts/qa-helper.sh --check resources
DEPLOY_LANG=en bash scripts/qa-helper.sh --fix resources
```

The helper checks the snapshot disk guard, defaulting to `400 GB` free, and
reports currently available memory. When disk is short, the remedy is a larger
SSD/NVMe filesystem or freed space, not casually bypassing the safety guard.

## Q: SSH disconnected, or the snapshot finished without subsequent startup.

```bash
DEPLOY_LANG=en bash scripts/qa-helper.sh --check interrupted
DEPLOY_LANG=en bash scripts/qa-helper.sh --fix interrupted --apply
```

The helper prints the `tmux` recovery path and ordered menu continuation steps.
With `--apply`, it reopens the interactive menu so you choose the correct
already-completed stage; it does not automatically overwrite data or re-download
the snapshot.

## Q: Why did `stake-indexer` not start?

Normal deployment requires `fractal-indexer` to produce a valid statehash at the
configured official reward-start height first. Refusing to start stake before
that is a safety gate, not an error.

```bash
DEPLOY_LANG=en bash scripts/qa-helper.sh --check statehash
DEPLOY_LANG=en bash scripts/qa-helper.sh --fix statehash
```

The remediation path keeps `fractal-indexer` running until catch-up; it does not
bypass statehash verification.

## Q: How do I tell if deployed services are healthy?

```bash
DEPLOY_LANG=en bash scripts/qa-helper.sh --check health
DEPLOY_LANG=en bash scripts/qa-helper.sh --fix health
```

The health check covers container state, OOM/exits, internal-port binding,
`fractal-indexer` API, statehash, `stake-indexer` status, and reward sync. The
fix path returns you to the menu for log inspection or deliberate service
restart after reviewing the failure.

## Q: Can proof-publisher silently sign or broadcast?

Not by default. Its prepared configuration must preserve:

```json
"dry_run": true,
"disable_broadcast": true
```

```bash
DEPLOY_LANG=en bash scripts/qa-helper.sh --check proof
DEPLOY_LANG=en bash scripts/qa-helper.sh --fix proof --apply
```

If the config was changed to allow broadcasting, the apply action first makes a
permission-restricted backup, then restores both safety switches to `true` and
validates again. The backup may still hold secrets and must remain private.

## Q: Can one-click operator registration run after official launch?

Not yet. Real registration and broadcasting are intentionally disabled today.

```bash
DEPLOY_LANG=en bash scripts/qa-helper.sh --check registration
DEPLOY_LANG=en bash scripts/qa-helper.sh --fix registration
```

The helper presents the review checklist that a future official registration
flow must satisfy; it does not bypass unpublished rules.

## Q: Can dynamic commission or custom staking behavior be added here?

This open-source deployment project remains official-only. It does not include
dynamic commission or custom staking behavior.

```bash
DEPLOY_LANG=en bash scripts/qa-helper.sh --check scope
```

Experimental code belongs in a separate research project so ordinary users do
not deploy incompatible rules by accident.

## Q: How do I avoid publishing RPC passwords, private keys, or API keys?

```bash
DEPLOY_LANG=en bash scripts/qa-helper.sh --check secrets
DEPLOY_LANG=en bash scripts/qa-helper.sh --fix secrets
```

The helper checks whether git tracks common generated config, data, or log
paths. If a secret was already published, rotate it immediately; deleting it in
a later commit does not make the leaked secret safe again.

## Q: What should I attach to an issue?

Generate a first-line report that does not read RPC passwords, wallet keys, or
generated config contents:

```bash
DEPLOY_LANG=en bash scripts/qa-helper.sh --fix issue-report --apply
```

The report can still contain paths or listener information; sanitize it once
more before posting publicly. When a new problem becomes frequent, it can be
added here and to the helper as another executable topic.
