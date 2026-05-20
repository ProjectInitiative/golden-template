# ProjectInitiative Golden Template

Standards, documentation, and scaffolding for Nix-based projects across the organization.

## Quick Start

### Scaffold a New Project

```bash
# Python (uv2nix)
nix flake init -t github:projectinitiative/golden-template#python

# Rust (crane)
nix flake init -t github:projectinitiative/golden-template#rust

# Go
nix flake init -t github:projectinitiative/golden-template#go

# Node/JS
nix flake init -t github:projectinitiative/golden-template#node

# Embedded (ESP-IDF/Arduino)
nix flake init -t github:projectinitiative/golden-template#embedded

# Container (Nix-built OCI)
nix flake init -t github:projectinitiative/golden-template#container

# Dev shell only (tools, no build)
nix flake init -t github:projectinitiative/golden-template#dev-shell

# Ingestion pipeline (S3/NATS/K8s)
nix flake init -t github:projectinitiative/golden-template#ingestion-pipeline

# Shared Nix library
nix flake init -t github:projectinitiative/golden-template#nix-library

# NixOS system configuration
nix flake init -t github:projectinitiative/golden-template#nixos-config
```

### Convert an Existing Project

See [MIGRATION_GUIDE.md](./MIGRATION_GUIDE.md) for detailed per-type conversion instructions.

## Repository Structure

```
flake.nix              # Root flake — exposes all templates
AGENTS.md              # Global agent working guide
DESIGN.md              # Architecture decisions
SOP.md                 # Standard Operating Procedures
MIGRATION_GUIDE.md     # Conversion guide
base-prompt.txt        # Extended agentic conversion prompt
docs/
  ci-strategies.md     # CI approach comparison
  project-type-reference.md  # Detailed per-type patterns
templates/
  python-uv2nix/       # Python + uv2nix template
  rust-crane/          # Rust + crane template
  go/                  # Go template
  node-js/             # Node/JS template
  embedded/            # ESP-IDF/Arduino template
  container/           # Nix-built OCI template
  dev-shell/           # Dev shell only template
  nix-library/         # Nix library template
  nixos-config/        # NixOS system config template
```

## Standardized Flake Outputs

Every project flake provides:

| Output              | Description                                     |
| ------------------- | ----------------------------------------------- |
| `packages.default`  | Main build artifact                             |
| `devShells.default` | Development environment (inherits from package) |
| `checks`            | Formatting, tests, and optional lint checks     |
| `formatter`         | Code formatter (nixfmt)                         |
