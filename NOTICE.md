# Notice

Fractal Indexer One-Click is a community packaging and operator workflow around
the official Fractal Bitcoin indexer deployment stack.

This project does not ship modified Fractal service binaries. The deployment
menu validates and runs official Docker image repositories:

- `fractalbitcoin/fractal-indexer`
- `fractalbitcoin/stake-indexer`
- `fractalbitcoin/fractal-proof-publisher`

Official service configuration templates are fetched at runtime from the public
Fractal Bitcoin deployment layout. The default upstream repositories are:

- https://github.com/fractal-bitcoin/fractal-indexer
- https://github.com/fractal-bitcoin/stake-indexer
- https://github.com/fractal-bitcoin/fractal-proof-publisher
- https://github.com/fractal-bitcoin/fractal-indexer-deploy

The wrapper scripts and documentation in this repository are released under the
MIT license in `LICENSE`. Upstream service source code and Docker images remain
under their respective upstream licenses and release policies.

This first release intentionally does not install, configure, or sync a
Fractald node. Users must provide a working Fractald RPC/ZMQ endpoint.
