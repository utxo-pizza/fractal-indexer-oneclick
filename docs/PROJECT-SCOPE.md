# Project Scope

This repository is the first standalone one-click package for deploying the
Fractal indexer stack when a Fractald node already exists.

## In Scope

- Guided bilingual deployment menu.
- Environment and dependency checks.
- Optional dependency installation for the indexer stack.
- Fractald RPC/ZMQ configuration collection.
- Fractald connectivity validation from Docker networking.
- Official `fractal-indexer` snapshot restore.
- Official `fractal-indexer` startup.
- Official `stake-indexer` startup after statehash readiness.
- Optional `proof-publisher` dry-run configuration.
- Disabled future one-click operator registration entry that refuses real
  registration until official third-party operator rules are public and stable.
- Persistent-session wrapper for long-running SSH work.
- GitHub-ready documentation and issue templates.

## Planned After Official Registration Opens

- One-click operator registration as a separate explicit menu action.
- Pre-broadcast review of the transaction, fee, inscription payload, and
  owner/change/reward addresses.
- A required second confirmation before any real broadcast.

## Out of Scope

- Installing Fractald.
- Syncing a Fractald node.
- Managing validator or staking wallet funds.
- Changing commission rates.
- Dynamic commission algorithms.
- Modifying FIP-101 rules.
- Running local patched service images.
- Automatically broadcasting real proof or registration transactions.

## Official-Only Boundary

The deploy menu validates official Docker image repositories and refuses local
modified service images. This package is an operator workflow, not a protocol
fork.
