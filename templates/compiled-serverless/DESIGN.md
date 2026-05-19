# Design: Compiled Serverless with Multi-Arch Builds

## Problem

Applications built in compiled languages (Go, Rust) are typically deployed as
monolithic binaries. To adopt serverless patterns (Fission, AWS Lambda, etc.),
developers often end up maintaining separate entry points or entirely separate
codebases for serverless vs. monolithic deployment.

## Solution: Multi-Headed Binary

Inspired by the [Fission](https://fission.io) serverless framework's `fission-bundle`
pattern ([source](https://github.com/fission/fission/blob/main/cmd/fission-bundle/main.go)):

**A single compiled binary that dispatches to different modes via subcommands.**

```
my-service server     → Monolith HTTP server
my-service function   → Fission serverless function
my-service worker     → Background worker (future)
```

### Benefits

1. **Write once, deploy anywhere** — Business logic lives in `pkg/` (Go) or
   `src/lib.rs` (Rust) and is shared across all entry points.

2. **Progressive deployment** — Start with a monolith. Split into functions when
   scale demands it. No code changes needed.

3. **Same binary, different CMD** — The OCI container for the Fission function uses
   the exact same binary, just with a different `ENTRYPOINT` (`my-service function`
   vs `my-service server`).

4. **Multi-arch by default** — Using Nix's `genAttrs`, both `x86_64-linux` and
   `aarch64-linux` are built from the same source with identical dependencies.

5. **Language-agnostic** — The same architecture pattern works for Go and Rust.
   The `flake.nix` builds both via `buildGoModule` and `craneLib.buildPackage`.

### When to Add a New Mode

- **New Fission function** → Add a new case in `main.go` / `src/main.rs`, create a
  lightweight runner that imports the shared library.
- **New background worker** → Same pattern. The runner starts a long-lived process,
  the library contains the logic.

## Multi-Arch Build Strategy

```
supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
```

Nix builds each system independently. On CI, use:

- **Native builders** — GitHub Actions `ubuntu-latest` (amd64) + `ubuntu-24.04-arm` (arm64)
- **QEMU emulation** — For cross-building containers
- **Remote builders** — Nix build farm for all architectures

Container images are per-architecture with a multi-arch manifest published to
GHCR via `nix run .#push-multi-arch`.

## Language Comparison

| Aspect | Go | Rust |
| ------ | -- | ---- |
| Build tool | `buildGoModule` | `craneLib.buildPackage` |
| Multi-arch | `CGO_ENABLED=0` + cross-compile | Target triples via rustc |
| HTTP server | `net/http` stdlib | `tokio` + `hyper` or `axum` |
| Shared logic | `pkg/handler/handler.go` | `src/lib.rs` |
| Entry points | `main.go` + `cmd/function/main.go` | `src/main.rs` + `src/bin/function.rs` |

## Comparison: Separate Binaries vs. Single Binary

| Approach | Pros | Cons |
| -------- | ---- | ---- |
| **Single multi-headed binary** | One build, one artifact, one dependency graph | Binary includes all modes (slightly larger) |
| **Separate binaries per mode** | Minimal binary per function | Duplicated deps, more CI time, drift risk |

This template defaults to the **multi-headed binary** approach because it
minimizes the delta between monolith and serverless deployments.

## Relationship to Fission

Fission functions are HTTP servers. The framework manages the lifecycle —
scaling, routing, logging. Your function binary just needs to:

1. Listen on the port provided by `FISSION_FUNCTION_PORT`
2. Serve HTTP requests
3. Exit cleanly on SIGTERM

Both Go (`cmd/function/main.go`) and Rust (`src/bin/function.rs`) follow this
contract. The `container-monolith-as-function` target shows how the same monolith
binary can be deployed as a Fission function by passing `function` as the CMD.
