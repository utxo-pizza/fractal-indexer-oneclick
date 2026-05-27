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
