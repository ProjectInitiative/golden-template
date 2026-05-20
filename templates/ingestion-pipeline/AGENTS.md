# Agent Working Guide — Ingestion Pipeline

## Environment

This project uses **uv2nix** for dependency management. The dev environment is loaded automatically via `direnv`.

## Repository Structure

```
flake.nix              # Nix flake — uv2nix Python build + devShell
pyproject.toml         # Python project metadata + deps
AGENTS.md              # This file
DESIGN.md              # Architecture & design decisions
src/ingestion_pipeline/ # Python Fission functions
  api/
    upload_handler.py  # Presigned URL generator endpoint
    confirm_handler.py # NATS JetStream publisher on upload confirm
    orchestrator.py    # NATS-triggered K8s job creator
frontend/              # Browser upload UI
  index.html
  app.js
  style.css
k8s/                   # Kubernetes manifests
  nats.yaml            # NATS JetStream StatefulSet + Service
  transcode-job.yaml   # Ephemeral batch Job template
  fission-functions.yaml
tests/                 # Python tests
```

## Key Architecture Points

- **Zero proxy bottleneck**: Files upload directly from browser to S3 via presigned URLs
- **Fission serverless**: Lightweight Python endpoints for auth, confirm, and orchestration
- **NATS JetStream**: Durable message queue with retries + DLQ; Fission MQ trigger invokes orchestrator
- **Ephemeral K8s Jobs**: Long-lived processing runs as batch Jobs, decoupled from FaaS time limits
- **S3-compatible storage**: Garage, MinIO, or any S3-compatible object store

## Available Commands

| Command                                  | Description      |
| ---------------------------------------- | ---------------- |
| `nix develop --command uv run pytest`    | Run tests        |
| `nix develop --command uv add <package>` | Add Python dep   |
| `nix develop --command uv lock`          | Update lockfile  |
| `nix develop --command ruff check`       | Lint Python code |
| `nix develop --command treefmt`          | Format all code  |

## Mandatory Pre-Submission

```bash
nix develop --command agent-check
```

This runs: working tree check → formatting → tests → nix build.

## Adding a New Python Dependency

1. `nix develop --command uv add <package>`
2. `nix develop --command uv lock`
3. Ensure it works: `nix develop --command uv run pytest`

The `flake.nix` reads from `pyproject.toml` + `uv.lock` automatically.
