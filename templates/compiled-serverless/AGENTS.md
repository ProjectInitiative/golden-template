# Agent Working Guide — Compiled Serverless (Multi-Arch)

## Architecture Pattern

This project follows the **multi-headed binary** pattern from the Fission serverless
framework. A single compiled binary dispatches to different modes via subcommands,
inspired by `fission-bundle`:

### Go

```
my-service server     → Monolith HTTP server (port 8080)
my-service function   → Fission serverless function (port 8888)
```

### Rust

```
my-service-rust server     → Monolith HTTP server (port 8080)
my-service-rust function   → Fission serverless function (port 8888)
```

**Key insight:** Shared business logic (`pkg/handler/` in Go, `rust/src/lib.rs` in Rust)
powers both deployment modes. Write your logic once, deploy as either:

- A standalone monolith binary
- A Fission serverless function
- Both simultaneously, scaled independently

## Multi-Arch Build Strategy

Targets `x86_64-linux` and `aarch64-linux` via `nixpkgs.lib.genAttrs`. Nix handles
cross-compilation naturally. Containers are per-architecture with multi-arch
manifests via `nix run .#push-multi-arch`.

## Available Commands

| Command                                                 | Description              |
| ------------------------------------------------------- | ------------------------ |
| `nix develop --command go build ./...`                  | Build all Go packages    |
| `nix develop --command go test ./...`                   | Run Go tests             |
| `nix develop --command go run . -- server`              | Run Go monolith          |
| `nix develop --command go run . -- function`            | Run Go Fission function  |
| `nix develop --command cargo build`                     | Build Rust               |
| `nix develop --command cargo test`                      | Run Rust tests           |
| `nix build .#default`                                   | Go monolith binary       |
| `nix build .#fission-function`                          | Go function binary       |
| `nix build .#rust-monolith`                             | Rust monolith binary     |
| `nix build .#rust-function`                             | Rust function binary     |
| `nix build .#container-monolith`                        | Go monolith OCI image    |
| `nix build .#container-function`                        | Go function OCI image    |
| `nix build .#container-rust-function`                   | Rust function OCI image  |
| `nix run .#push-multi-arch -- <attr> <name> <registry>` | Push multi-arch manifest |

## Targets

| Package                                   | Lang | Description                                    |
| ----------------------------------------- | ---- | ---------------------------------------------- |
| `packages.default`                        | Go   | Multi-headed monolith binary                   |
| `packages.fission-function`               | Go   | Standalone Fission function binary             |
| `packages.rust-monolith`                  | Rust | Multi-headed monolith binary                   |
| `packages.rust-function`                  | Rust | Standalone Fission function binary             |
| `packages.container-monolith`             | Go   | OCI image for monolith mode                    |
| `packages.container-function`             | Go   | OCI image for function mode                    |
| `packages.container-monolith-as-function` | Go   | Monolith binary deployed as a Fission function |
| `packages.container-rust-monolith`        | Rust | OCI image for Rust monolith                    |
| `packages.container-rust-function`        | Rust | OCI image for Rust function                    |
| `apps.build-all`                          | —    | Build all targets sequentially                 |

## Mandatory Pre-Submission

```bash
nix develop --command agent-check
```

This runs: formatting check → tests → build verification.

## Adding Dependencies

### Go

1. `nix develop --command go get <module>`
2. `nix develop --command go mod tidy`
3. Update `vendorHash` in `flake.nix`

### Rust

1. `nix develop --command cargo add <crate>`
2. `nix develop --command cargo build`
3. For sys crates, add system libs to `rustCommon.buildInputs`

## Deploying to Fission

```bash
# Load the function container
docker load < result-container-function

# Or push to a registry
nix run .#push-multi-arch -- container-function my-fn ghcr.io/my-org

# Create Fission environment + function
fission environment create --name go-env --image ghcr.io/my-org/my-fn
fission function create --name my-fn --env go-env
fission route create --method GET --url / --function my-fn
```
