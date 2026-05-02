# Design Philosophy — ProjectInitiative Nix Standards

## Why Nix?

Nix provides **reproducible builds**, **hermetic development environments**, and **declarative configuration** across all our projects. Every repository should be self-contained: check it out, run `direnv allow` (or `nix develop`), and all tools and dependencies are available — no manual `apt install`, `pip install`, or `npm install` needed.

## Core Design Decisions

### 1. Flakes Are the Standard Interface

Every project exposes a flake with standardized outputs:

- `packages.${system}.default` — The main build artifact
- `devShells.${system}.default` — Development environment (inherits from `default` when applicable)
- `checks.${system}` — CI-compatible checks (formatting, tests, build)
- `formatter.${system}` — Code formatter (nixfmt or treefmt wrapper)

This standardization means:
- CI scripts are trivial (`nix flake check && nix build`)
- Agents know exactly what to call
- Users get a consistent experience across projects

### 2. DRY Dependency Management

Dependencies are declared **once** in the package derivation, and `devShells` inherit them via `inputsFrom`. This prevents:

- Drift between dev and CI environments
- Duplicated package lists
- "Works on my machine" issues

Exception: Pure dev-shell projects (tools only, no package build) define dependencies directly in `mkShell`.

### 3. Multi-Architecture by Default

All flakes support `x86_64-linux` and `aarch64-linux` at minimum, using `flake-utils` or manual `genAttrs`. Container projects add `x86_64-darwin` and `aarch64-darwin` as appropriate.

### 4. Divergent Build vs. Dev Strategies

Recognizing that sandboxed builds (`nix build`) can be slow, we support two workflows:

| Workflow | Command | Use When |
|----------|---------|----------|
| **Iterative dev** | `nix develop --command cargo build` | Fast iteration during development |
| **Sandbox verification** | `nix build` | Final validation before commit/CI |

The `nix develop` approach uses the exact same dependencies (via `inputsFrom`) but skips the sandbox, allowing incremental compilation.

### 5. Shared Libraries over Copy-Paste

Common patterns (container build/push, CI scripts, formatter configs) are extracted into shared flakes (`ops-utils`, `treefmt-nix`) rather than duplicated per project.

## Per-Type Architectures

### Python (uv2nix)

Modern Python projects avoid `python3.withPackages` and instead use `uv2nix` + `pyproject.nix` for:
- Lockfile-pinned dependencies (via `uv.lock`)
- Proper build-system awareness (setuptools, maturin, etc.)
- C-extension handling via `overrideScope`

### Rust (crane)

Rust projects use `crane` (not `buildRustPackage`) for:
- Split dependency caching (`buildDepsOnly` + `buildPackage`)
- Incremental compilation in dev shell
- Proper `sys` crate handling (pkg-config, system libs)

### Embedded (ESP-IDF / Arduino)

Embedded projects use `esp-dev` for ESP-IDF toolchain or `arduino-nix` for Arduino toolchain, with:
- All tooling provided via Nix (no manual SDK installs)
- Host-side tests in the same flake
- Firmware build artifacts exposed as `packages.default`

### Containers

Container images are built with `dockerTools.buildImage` or `streamLayeredImage` and pushed via shared `ops-utils` scripts. Multi-arch manifests are created for GHCR publishing.

## CI Philosophy

- **Run fast**: `nix flake check` runs formatting + tests (no build needed)
- **Run once**: `nix build` runs full sandboxed build after checks pass
- **Cache everything**: Use Attic or Cachix for shared binary caches across projects
- **Matrix naturally**: Multi-arch comes free with the flake pattern

## Future Directions

1. **Module system**: Extract common `nix/` modules into a shared library (like ops-utils but for build logic)
2. **Auto-generation**: Tooling to scan a repo and generate `flake.nix` from existing build files
3. **Flake parts**: Evaluate `flake-parts` for even more structured flake composition
