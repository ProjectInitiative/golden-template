# Agent Working Guide — Wrapper Project

## What Is This?

This repo does **not** contain the source code directly. Instead, it wraps an **upstream project** (fetched via Nix flake inputs) with:

- A reproducible build derivation
- Local iteration workflow (copy source to `.direnv/vendor/`)
- Optional NixOS module for system services

## Environment

Loaded via `direnv`. Source code is fetched by Nix, not committed here.

## Workflow

### Sandboxed Build (CI-ready)

```bash
nix build          # Builds from pinned flake input
```

### Local Iteration (for development)

```bash
setup-local-source  # Copy source to .direnv/vendor/upstream for editing
# Edit files in .direnv/vendor/upstream/
build-local         # Build from local copy
```

## Available Commands

| Command              | Description                                  |
| -------------------- | -------------------------------------------- |
| `setup-local-source` | Copy upstream source into `.direnv/vendor/`  |
| `build-local`        | Build from the local editable copy           |
| `nix build`          | Build from pinned flake input (reproducible) |

## Mandatory Pre-Submission

```bash
nix develop --command agent-check
```

## Why This Pattern?

- The upstream project may never accept Nix upstream (personal fork/tinkering)
- Keeps the repo small (only Nix logic, not the full source)
- Pins exact upstream version via flake lock
- Provides both hermetic builds and fast local iteration
