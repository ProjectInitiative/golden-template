# Agent Working Guide — Python Project

## Environment

This project uses **uv2nix** for dependency management. The dev environment is loaded automatically via `direnv`.

## Available Commands

| Command | Description |
|---------|-------------|
| `nix develop --command uv run pytest` | Run tests |
| `nix develop --command uv run python main.py` | Run main app |
| `nix develop --command uv add <package>` | Add dependency |
| `nix develop --command uv lock` | Update lockfile |
| `nix develop --command ruff check` | Lint code |
| `nix develop --command mypy .` | Type check |

## Mandatory Pre-Submission

```bash
nix develop --command agent-check
```

This runs: formatting check → tests → build verification.

## Adding a New Dependency

1. `nix develop --command uv add <package>`
2. `nix develop --command uv lock`
3. Ensure it works: `nix develop --command uv run pytest`

The `flake.nix` reads from `pyproject.toml` + `uv.lock` automatically, so no manual flake edits for Python deps.
