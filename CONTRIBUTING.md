# Contributing

Thank you for improving this deployment package.

## Development Rules

- Keep this project official-version-only.
- Do not add Fractald node installation to this first indexer-stack package.
- Do not add dynamic commission logic or staking rule changes.
- Do not commit private keys, RPC passwords, API keys, generated `chain.yaml`,
  generated `config.json`, runtime Compose files, logs, or data directories.
- Keep user-facing docs bilingual when changing deployment behavior.

## Local Checks

```bash
bash -n scripts/*.sh
bash scripts/deploy-menu.sh --self-test
```

If Docker is available, also run:

```bash
bash scripts/deploy-menu.sh --doctor
```

## Pull Requests

Describe:

- what changed
- why it is needed
- whether it changes service behavior or only operator UX
- what commands were used for verification
