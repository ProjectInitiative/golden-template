# Agent Working Guide — Go Project

## Environment

Standard Go module built with `buildGoModule` in Nix.

## Available Commands

| Command                               | Description          |
| ------------------------------------- | -------------------- |
| `nix develop --command go build`      | Build                |
| `nix develop --command go test ./...` | Run tests            |
| `nix develop --command go fmt ./...`  | Format code          |
| `nix develop --command go vet ./...`  | Vet code             |
| `nix build`                           | Full sandboxed build |

## Mandatory Pre-Submission

```bash
nix develop --command agent-check
```

## Adding a Dependency

1. `nix develop --command go get <module>`
2. Update vendor: `nix develop --command go mod tidy && nix develop --command go mod vendor`
3. Update `vendorHash` in `flake.nix` by setting to `""`, building, and copying the hash
