# Beginner Difficulty Guide

This page answers one practical question: how hard is this one-click script for a
non-operator to use?

## Short Answer

If the server already has a working Fractald node and Docker containers can reach
its RPC/ZMQ endpoints, this is a fairly simple semi-automatic deployment. Menu
option `1` is beginner mode; it tries to reduce interaction to RPC password
confirmation plus final deployment approval.

If you do not have a Fractald node yet, or you do not know what RPC/ZMQ means,
this project is not a full from-zero installer. Installing, syncing, and exposing
Fractald RPC/ZMQ is a prerequisite and is outside the first release scope.

Think of it this way:

```text
Working Fractald exists: easy, mostly confirm defaults
Fractald config is non-standard: medium, RPC/ZMQ needs checking
Fresh empty server: not beginner-proof yet, prepare the node first
```

## What The Menu Automates

The menu automates these parts:

- Fetching the official `fractal-bitcoin/fractal-indexer-deploy` bundle.
- Checking or installing common dependencies such as Docker, Docker Compose,
  curl, tar, zstd, and git.
- Trying to detect local Fractald config files and process flags.
- Writing `chain.yaml` for `fractal-indexer` and `stake-indexer`.
- Generating Docker container memory limits from currently available memory.
- Restoring the official `fractal-indexer` snapshot.
- Starting `fractal-indexer`.
- Waiting for the FIP-101 statehash prerequisite.
- Starting `stake-indexer`.
- Running post-deployment health checks.
- Binding internal datastore ports to `127.0.0.1` by default.

## What A Beginner Usually Confirms

If Fractald is local and uses a standard setup, menu option `1` uses these
defaults automatically:

- Install dependencies: yes.
- Clone source repositories for research: no.
- Resource mode: `auto 70%`.
- Restore official snapshot: yes.
- Stop conflicting services: yes.
- Require statehash before starting `stake-indexer`: yes.
- proof-publisher: no.

When detection succeeds, you usually only confirm:

- Fractald RPC password.
- Final deployment plan.

If auto-detection fails, switch to menu option `2` and manually confirm:

- Fractald RPC URL, usually `http://fractald:8332`.
- Fractald ZMQ block URL, usually `tcp://fractald:10330`.
- Fractald ZMQ tx URL, usually `tcp://fractald:10331`.
- Fractald RPC username.

## Where Beginners Usually Get Stuck

The common blockers are Fractald prerequisites, not the indexer stack itself:

- Fractald is not synced past the snapshot height.
- Fractald RPC only listens on `127.0.0.1`, so Docker containers cannot reach it.
- The RPC port is wrong. The common current setup is `8332`; not every default in
  older docs matches your node.
- ZMQ is not enabled, or the ports are not `10330` / `10331`.
- A pruned node has `pruneheight` higher than the official snapshot height
  `1753260`.
- The server does not have enough free disk for snapshot restore.

When unsure, run:

```bash
bash scripts/deploy-menu.sh --doctor
```

It does not restore snapshots, write production config, or start services. It
only runs a readiness diagnosis.

## Simplest Recommended Path

```bash
git clone https://github.com/utxo-pizza/fractal-indexer-oneclick.git
cd fractal-indexer-oneclick
bash scripts/run-menu-persistent.sh
```

Then:

1. Select a language.
2. Select menu option `1`.
3. Let the script diagnose Fractald.
4. Confirm the RPC password.
5. Review the plan, then confirm execution.

## Why It Is Not Fully No-Brainer Yet

This project deploys the official indexer service stack. It does not install or
sync Fractald.

The user still needs to know:

- Where Fractald is running.
- The RPC username and password.
- Whether RPC/ZMQ are reachable from Docker containers.
- Whether the server has enough memory and disk.

Once those are ready, most of the remaining deployment flow is automated.
