# Agent Working Guide — Go Project

## Environment

This project uses **devenv** for the development environment. The dev shell is loaded automatically via `direnv`. The project is built with `buildGoModule` for sandboxed Nix builds.

## Available Commands

| Command                         | Description          |
| ------------------------------- | -------------------- |
| `devenv shell -- go build`      | Build                |
| `devenv shell -- go test ./...` | Run tests            |
| `devenv shell -- go fmt ./...`  | Format code          |
| `devenv shell -- go vet ./...`  | Vet code             |
| `devenv test`                   | Run test suite       |
| `nix build`                     | Full sandboxed build |

## Mandatory Pre-Submission

```bash
nix develop --command agent-check
```

## Adding a Dependency

1. `devenv shell -- go get <module>`
2. Update vendor: `devenv shell -- go mod tidy && devenv shell -- go mod vendor`
3. Update `vendorHash` in `flake.nix` by setting to `""`, building, and copying the hash
