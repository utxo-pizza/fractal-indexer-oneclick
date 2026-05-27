# Security Policy

## Supported Scope

This repository supports the deployment wrapper, menu, documentation, and
bundled configuration templates for the official Fractal indexer stack.

It does not provide support for compromised wallets, leaked private keys, or
custom modified service images.

## Reporting A Vulnerability

Please do not open public issues containing:

- RPC passwords
- private keys or seed phrases
- UniSat API keys
- server root passwords
- full production configuration files

Open a private security advisory if available, or contact the repository owner
through a private channel.

## Operator Defaults

- Keep Fractald RPC private.
- Firewall public API ports unless public access is intentional.
- Keep internal datastore ports bound to `127.0.0.1`.
- Run proof-publisher in dry-run mode until registration/proof broadcasting is
  deliberately reviewed.

## High-Risk Operator Checks

### Fractald RPC/ZMQ Public Exposure

Do not expose Fractald RPC to the public Internet.

Check local listeners:

```bash
DEPLOY_LANG=en bash scripts/qa-helper.sh --check rpc-exposure
```

If `8332`, `10332`, `10330`, or `10331` listens on `0.0.0.0` or `[::]`, confirm
that a firewall restricts inbound sources. First confirm the Docker/container
network that must still be allowed:

```bash
docker network inspect bridge --format '{{(index .IPAM.Config 0).Subnet}}'
```

Prefer binding Fractald to `127.0.0.1` and the Docker bridge IP instead of
`0.0.0.0`.

The Q&A helper previews this remediation and, only for host-run Fractald with an
already active `ufw` firewall, can apply port-protection rules after explicit
approval:

```bash
QA_DOCKER_CIDR=172.17.0.0/16 DEPLOY_LANG=en \
  bash scripts/qa-helper.sh --fix rpc-exposure --apply
```

Replace `172.17.0.0/16` with the confirmed container CIDR for the host. The
helper inserts allow/deny rules before older broad allow rules, then prints
`sudo ufw status numbered` for review.

### Generated Secrets

Generated files can contain RPC passwords, private keys, or API keys:

```bash
find . -path './.official/*' -prune -o -type f \
  \( -name 'chain.yaml' -o -name 'config.json' \) -print
```

Do not commit or post those files. Run `git status --short` before pushing.
You can also run:

```bash
DEPLOY_LANG=en bash scripts/qa-helper.sh --check secrets
```
