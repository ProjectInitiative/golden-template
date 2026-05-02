# Agent Working Guide — Rust Project

## Environment

This project uses **crane** for incremental Rust builds. The toolchain is pinned via `fenix`.

## Available Commands

| Command | Description |
|---------|-------------|
| `nix develop --command cargo build` | Build (incremental) |
| `nix develop --command cargo test` | Run tests |
| `nix develop --command cargo fmt` | Format code |
| `nix develop --command cargo clippy` | Lint |
| `nix build` | Full sandboxed build |

## Mandatory Pre-Submission

```bash
nix develop --command agent-check
```

This runs: formatting check → tests → build verification.

## Adding a Dependency

1. `nix develop --command cargo add <crate>`
2. Build and test: `nix develop --command cargo build && nix develop --command cargo test`
3. For sys crates, add system libs to `commonArgs.buildInputs` in `flake.nix`
