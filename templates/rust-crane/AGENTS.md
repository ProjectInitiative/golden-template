# Agent Working Guide — Rust Project

## Environment

This project uses **crane** for incremental Rust builds and **devenv** for the development environment. The toolchain is pinned via `fenix`. The dev shell is loaded automatically via `direnv`.

## Available Commands

| Command                        | Description          |
| ------------------------------ | -------------------- |
| `devenv shell -- cargo build`  | Build (incremental)  |
| `devenv shell -- cargo test`   | Run tests            |
| `devenv shell -- cargo fmt`    | Format code          |
| `devenv shell -- cargo clippy` | Lint                 |
| `devenv test`                  | Run test suite       |
| `nix build`                    | Full sandboxed build |

## Mandatory Pre-Submission

```bash
nix develop --command agent-check
```

This runs: formatting check → tests → build verification.

## Adding a Dependency

1. `devenv shell -- cargo add <crate>`
2. Build and test: `devenv shell -- cargo build && devenv shell -- cargo test`
3. For sys crates, add system libs to `commonArgs.buildInputs` in `flake.nix`
