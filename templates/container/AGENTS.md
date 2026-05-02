# Agent Working Guide — Container Images

## Environment

Nix-built OCI container images using `dockerTools`. Multi-arch push via `ops-utils`.

## Available Commands

| Command | Description |
|---------|-------------|
| `nix run .#build-all` | Build all images and load into Docker |
| `nix run .#push-multi-arch -- <package> <image-name> <owner> [tag]` | Build + push multi-arch |
| `nix run .#build-image -- <flake-ref>` | Build and load single image |
| `nix build .#default` | Sandboxed build of container image |

## Mandatory Pre-Submission

```bash
nix develop --command agent-check
```

## Adding a New Container

1. Define the app derivation in `flake.nix`
2. Create a `dockerTools.buildImage` for it
3. Add to `packages` and register in CI push steps
