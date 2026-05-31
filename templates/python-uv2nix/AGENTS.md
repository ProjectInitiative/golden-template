# Agent Working Guide — Python Project

## Environment

This project uses **uv2nix** for dependency management and **devenv** for the development environment. The dev shell is loaded automatically via `direnv`.

## Available Commands

| Command                                 | Description     |
| --------------------------------------- | --------------- |
| `devenv shell -- uv run pytest`         | Run tests       |
| `devenv shell -- uv run python main.py` | Run main app    |
| `devenv shell -- uv add <package>`      | Add dependency  |
| `devenv shell -- uv lock`               | Update lockfile |
| `devenv shell -- ruff check`            | Lint code       |
| `devenv test`                           | Run test suite  |

## Mandatory Pre-Submission

```bash
nix develop --command agent-check
```

This runs: formatting check → tests → build verification.

## Adding a New Dependency

1. `devenv shell -- uv add <package>`
2. `devenv shell -- uv lock`
3. Ensure it works: `devenv shell -- uv run pytest`

The `flake.nix` reads from `pyproject.toml` + `uv.lock` automatically, so no manual flake edits for Python deps.
