# Project Migration Guide: flake-utils → devenv + flake-parts

> **Purpose:** This document is designed to be fed to an LLM (or followed by a human) to migrate any project scaffolded from the ProjectInitiative golden-template to the new devenv-based architecture.

---

## Migration Overview

### What Changes

| Aspect          | Before (Old Template)                                     | After (Devenv)                                           |
| --------------- | --------------------------------------------------------- | -------------------------------------------------------- |
| Flake structure | `flake-utils.lib.eachDefaultSystem`                       | `flake-parts.lib.mkFlake` + `devenv.flakeModule`         |
| Dev shell       | `pkgs.mkShell { packages = [...]; shellHook = ''...''; }` | `devenv.shells.default = { languages.X.enable = true; }` |
| Language tools  | Manual list (gopls, rust-analyzer, etc.)                  | Auto via `languages.<lang>.enable`                       |
| Services        | Manual shellHook scripts                                  | `services.<name>.enable = true` + `devenv up`            |
| Git hooks       | Manual or pre-commit-hooks.nix                            | `git-hooks.hooks.<name>.enable = true`                   |
| Process mgmt    | None (manual terminal splits)                             | `processes.<name>.exec` + `devenv up`                    |
| .envrc          | `use flake`                                               | `use flake` (unchanged)                                  |

### What Stays the Same

- `packages.default` derivation logic (buildGoModule, crane, uv2nix, etc.)
- `checks` definitions
- `formatter` definition
- `.envrc` with `use flake`
- Source code structure
- CI pipeline structure (may need minor command updates)

---

## Step-by-Step Migration

### Step 1: Identify Project Type

Determine which template the project was based on by examining `flake.nix`:

| Indicator in `flake.nix`                         | Project Type        |
| ------------------------------------------------ | ------------------- |
| `uv2nix` input, `pyproject.toml` exists          | Python (uv2nix)     |
| `crane` + `fenix` inputs, `Cargo.toml` exists    | Rust (crane)        |
| `buildGoModule`, `go.mod` exists                 | Go                  |
| `buildNpmPackage`, `package.json` exists         | Node.js             |
| No package build, just `mkShell`                 | Dev Shell           |
| `dockerTools.buildImage`                         | Container           |
| `upstream-src` input, `.direnv/vendor/` workflow | Wrapper             |
| Multiple languages + `ops-utils`                 | Compiled Serverless |

---

### Step 2: Update `flake.nix` Inputs

**BEFORE (common pattern):**

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  flake-utils.url = "github:numtide/flake-utils";
  # ... other inputs
};
```

**AFTER:**

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  flake-parts.url = "github:hercules-ci/flake-parts";
  flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  devenv.url = "github:cachix/devenv";
  devenv.inputs.nixpkgs.follows = "nixpkgs";
  # ... keep other inputs (crane, uv2nix, ops-utils, etc.)
};

nixConfig = {
  extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
  extra-substituters = "https://devenv.cachix.org";
};
```

**Remove:** `flake-utils` input (replaced by `flake-parts`)

---

### Step 3: Restructure `flake.nix` Outputs

**BEFORE:**

```nix
outputs = { self, nixpkgs, flake-utils, ... }:
  flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      packages.default = ...;
      devShells.default = pkgs.mkShell { ... };
      checks = { ... };
      formatter = pkgs.nixfmt;
    }
  );
```

**AFTER:**

```nix
outputs = inputs@{ flake-parts, ... }:
  flake-parts.lib.mkFlake { inherit inputs; } {
    imports = [
      inputs.devenv.flakeModule
    ];
    systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

    perSystem = { config, self', inputs', pkgs, system, ... }: {
      packages.default = ...;  # Keep existing build logic

      devenv.shells.default = {
        imports = [ ./devenv.nix ];
        packages = [ config.packages.default ];
      };

      checks = { ... };  # Keep existing checks
      formatter = pkgs.nixfmt;
    };

    flake = {
      # System-agnostic outputs (nixosModules, templates, etc.)
    };
  };
```

---

### Step 4: Create `devenv.nix`

Create a new `devenv.nix` file in the project root. Choose the appropriate template below based on project type.

---

## devenv.nix Templates by Project Type

### Python (uv2nix)

```nix
{ pkgs, config, ... }: {
  languages.python = {
    enable = true;
    venv.enable = true;
    venv.requirements = ''
      pytest
      ruff
      mypy
    '';
    uv.enable = true;
    uv.sync.enable = true;
  };

  packages = [ pkgs.uv ];

  enterShell = ''
    echo "Python dev environment"
    echo "Commands: uv run pytest, uv add <pkg>, uv lock"
  '';

  git-hooks.hooks = {
    ruff.enable = true;
    nixfmt-rfc-style.enable = true;
  };

  enterTest = ''
    uv run pytest tests/
  '';
}
```

### Rust (crane)

```nix
{ pkgs, ... }: {
  languages.rust = {
    enable = true;
    channel = "stable";
    components = [ "rustc" "cargo" "clippy" "rustfmt" "rust-analyzer" ];
  };

  packages = with pkgs; [
    cargo-edit
    cargo-watch
  ];

  enterShell = ''
    echo "Rust dev environment"
    echo "Commands: cargo build, cargo test, cargo fmt"
  '';

  git-hooks.hooks = {
    rustfmt.enable = true;
    clippy.enable = true;
    nixfmt-rfc-style.enable = true;
  };

  enterTest = ''
    cargo test
  '';
}
```

### Go

```nix
{ pkgs, ... }: {
  languages.go.enable = true;

  enterShell = ''
    echo "Go dev environment"
    echo "Commands: go build, go test, go fmt, go vet"
  '';

  git-hooks.hooks = {
    gofmt.enable = true;
    nixfmt-rfc-style.enable = true;
  };

  enterTest = ''
    go test ./...
  '';
}
```

### Node.js / TypeScript

```nix
{ pkgs, ... }: {
  languages.javascript = {
    enable = true;
    package = pkgs.nodejs_22;
    npm.install.enable = true;
  };

  enterShell = ''
    echo "Node.js dev environment"
    echo "Commands: npm run dev, npm test, npm run build"
  '';

  git-hooks.hooks = {
    prettier.enable = true;
    nixfmt-rfc-style.enable = true;
  };

  enterTest = ''
    npm test
  '';
}
```

### Dev Shell Only (no package build)

```nix
{ pkgs, ... }: {
  packages = with pkgs; [
    jq
    yq
    ripgrep
    fd
  ];

  enterShell = ''
    echo "Dev shell"
    echo "Available tools: jq, yq, rg, fd"
  '';

  git-hooks.hooks.nixfmt-rfc-style.enable = true;
}
```

### Compiled Serverless (Go + Rust)

```nix
{ pkgs, ... }: {
  languages.go.enable = true;
  languages.rust = {
    enable = true;
    channel = "stable";
  };

  enterShell = ''
    echo "Multi-language serverless dev environment"
    echo "Commands: go build, cargo build"
  '';

  git-hooks.hooks = {
    gofmt.enable = true;
    rustfmt.enable = true;
    nixfmt-rfc-style.enable = true;
  };

  processes = {
    go-server.exec = "go run . -- server";
    rust-server.exec = "cargo run -- server";
  };

  enterTest = ''
    go test ./...
    cargo test
  '';
}
```

### Wrapper Project

```nix
{ pkgs, ... }: {
  packages = with pkgs; [
    git
  ];

  scripts.setup-local-source.exec = ''
    echo "Setting up local source in .direnv/vendor..."
    mkdir -p .direnv/vendor
    if [ -d ".direnv/vendor/upstream" ]; then
      echo "Removing existing source..."
      rm -rf .direnv/vendor/upstream
    fi
    echo "Copying from Nix store..."
    cp -r ${inputs.upstream-src} .direnv/vendor/upstream
    chmod -R +w .direnv/vendor/upstream
    echo "Done. Source is in .direnv/vendor/upstream"
  '';

  scripts.build-local.exec = ''
    if [ ! -d ".direnv/vendor/upstream" ]; then
      echo "Error: Local source not found. Run 'setup-local-source' first."
      exit 1
    fi
    cd .direnv/vendor/upstream
    echo "Building from local source..."
    make
  '';

  enterShell = ''
    echo "Wrapper project dev shell"
    echo "Commands:"
    echo "  setup-local-source  : Copy source to .direnv/vendor/ for editing"
    echo "  build-local         : Build from local source copy"
    echo "  nix build           : Build from pinned flake input"
  '';

  git-hooks.hooks.nixfmt-rfc-style.enable = true;
}
```

---

### Step 5: Update `.gitignore`

Add devenv-specific entries:

```gitignore
# Add these lines to existing .gitignore
.devenv/
.devenv.flake.nix
```

---

### Step 6: Update `AGENTS.md`

Replace the commands table with devenv equivalents:

**BEFORE:**

```markdown
| Command                               | Description |
| ------------------------------------- | ----------- |
| `nix develop --command go build`      | Build       |
| `nix develop --command go test ./...` | Run tests   |
```

**AFTER:**

```markdown
| Command                      | Description          |
| ---------------------------- | -------------------- |
| `devenv shell`               | Enter dev shell      |
| `devenv shell go build`      | Build                |
| `devenv shell go test ./...` | Run tests            |
| `devenv up`                  | Start all processes  |
| `devenv test`                | Run test suite       |
| `nix build`                  | Full sandboxed build |
```

---

### Step 7: Verify Migration

```bash
# 1. Update flake lock
nix flake update

# 2. Check flake evaluates
nix flake check

# 3. Enter the shell
devenv shell

# 4. Run tests
devenv test

# 5. Build package
nix build
```

---

## Common Migration Patterns

### Pattern: Extracting Tools from `mkShell.packages`

**BEFORE:**

```nix
devShells.default = pkgs.mkShell {
  packages = with pkgs; [
    go
    gopls
    gotools
    delve
    rust-analyzer
  ];
};
```

**AFTER:**

```nix
# In devenv.nix
{
  languages.go.enable = true;      # Provides: go, gopls, gotools, delve
  languages.rust.enable = true;    # Provides: rustc, cargo, rust-analyzer
}
```

**Reference: Language Module Auto-Provided Tools**

| Language               | Auto-Provided Tools                                                     |
| ---------------------- | ----------------------------------------------------------------------- |
| `languages.go`         | go, gopls, delve, gotools, gomodifytags, impl, go-tools, gotests, iferr |
| `languages.rust`       | rustc, cargo, rustfmt, clippy, rust-analyzer (configurable)             |
| `languages.python`     | python, pip, venv (or uv/poetry), pyright                               |
| `languages.javascript` | nodejs, npm/pnpm/yarn/bun, typescript-language-server                   |
| `languages.c`          | clang-tools, gnumake, pkg-config, gdb/lldb, valgrind, ccls              |
| `languages.cplusplus`  | clang-tools, cmake, clang, ccls                                         |
| `languages.java`       | jdk, maven, gradle, jdt-language-server                                 |
| `languages.shell`      | bats, shellcheck, shfmt, bash-language-server                           |

---

### Pattern: Converting `shellHook` to `enterShell`

**BEFORE:**

```nix
devShells.default = pkgs.mkShell {
  shellHook = ''
    echo "Welcome!"
    export MY_VAR="hello"
  '';
};
```

**AFTER:**

```nix
# In devenv.nix
{
  enterShell = ''
    echo "Welcome!"
    export MY_VAR="hello"
  '';

  # Or use env for environment variables:
  env.MY_VAR = "hello";
}
```

---

### Pattern: Converting Manual Service Setup

**BEFORE:**

```nix
devShells.default = pkgs.mkShell {
  packages = [ pkgs.postgresql ];
  shellHook = ''
    export PGDATA="$PWD/.direnv/postgres"
    if [ ! -d "$PGDATA" ]; then
      initdb -D "$PGDATA"
    fi
    pg_ctl -o "-k $PGDATA" start
    trap 'pg_ctl stop' EXIT
  '';
};
```

**AFTER:**

```nix
# In devenv.nix
{
  services.postgres = {
    enable = true;
    initialDatabases = [{ name = "app_dev"; }];
  };
}
# Then run: devenv up
```

---

### Pattern: Converting `inputsFrom`

**BEFORE:**

```nix
devShells.default = pkgs.mkShell {
  inputsFrom = [ self.packages.${system}.default ];
  packages = with pkgs; [ extra-tool ];
};
```

**AFTER:**

```nix
# In flake.nix
devenv.shells.default = {
  imports = [ ./devenv.nix ];
  packages = [ config.packages.default pkgs.extra-tool ];
};
```

Or use `inputsFrom` in devenv.nix:

```nix
{
  inputsFrom = [ config.packages.default ];
  packages = [ pkgs.extra-tool ];
}
```

---

## Advanced: Adding Services

### PostgreSQL

```nix
services.postgres = {
  enable = true;
  package = pkgs.postgresql_16;
  initialDatabases = [
    { name = "myapp"; }
    { name = "myapp_test"; }
  ];
  initialScript = ''
    CREATE USER myapp WITH PASSWORD 'dev';
    GRANT ALL PRIVILEGES ON DATABASE myapp TO myapp;
  '';
  extensions = [ "pgvector" "postgis" ];
  port = 5432;
};
```

### Redis

```nix
services.redis = {
  enable = true;
  port = 6379;
};
```

### NATS

```nix
services.nats = {
  enable = true;
  port = 4222;
};
```

### MinIO (S3-compatible)

```nix
services.minio = {
  enable = true;
  buckets = [ "uploads" "avatars" ];
};
```

### Kafka

```nix
services.kafka = {
  enable = true;
  mode = "kraft";  # or "zookeeper"
};
```

---

## Advanced: Process Management

For long-running development servers:

```nix
{
  processes = {
    api.exec = "npm run dev:api";
    worker.exec = "npm run dev:worker";
    frontend.exec = "npm run dev:frontend";
  };
}
# Then run: devenv up
```

---

## Advanced: Container Building

devenv provides a `containers` module:

```nix
{
  containers.my-app = {
    name = "my-app";
    version = "latest";
    copyToRoot = [ config.packages.default ];
    startupCommand = [ "${config.packages.default}/bin/my-app" ];
  };
}
# Build: devenv container build my-app
```

---

## Troubleshooting

### Issue: `nix flake check` fails with "option 'devenv.shells' not found"

**Solution:** Ensure `inputs.devenv.flakeModule` is in the `imports` list:

```nix
imports = [ inputs.devenv.flakeModule ];
```

### Issue: Language tools not available in shell

**Solution:** Check that `languages.<name>.enable = true;` is set in `devenv.nix`.

### Issue: Services not starting

**Solution:** Use `devenv up` to start services, not `devenv shell`. Services are managed by the process manager.

### Issue: `devenv.root` resolves to nix store path (Read-only file system errors)

**Problem:** When using `use flake` via nix-direnv, `devenv.root = toString ./.` resolves to the nix store path during evaluation. The `devenv` CLI then tries to create `.devenv/` there and fails.

**Solutions (in order of preference):**

1. **Upgrade to devenv 2.x and use `use devenv`** — Install latest devenv and add the `use_devenv` function to `~/.config/direnv/lib/devenv.sh`:
   ```bash
   nix profile install github:cachix/devenv/latest
   ```
   ```bash
   # ~/.config/direnv/lib/devenv.sh
   use_devenv() {
     watch_file .envrc devenv.nix devenv.lock devenv.yaml
     eval "$(devenv direnv-export)"
   }
   ```
   Then use `use devenv` in `.envrc`. The `direnv-export` command handles `DEVENV_ROOT` correctly at runtime.

2. **Use `devenv shell -- ...`** instead of direnv integration — works with any version.

### Issue: `cachix.enable` causes auth errors with private caches

**Problem:** `devenv`'s built-in cachix integration tries to manage binary caches, which may conflict with system-level nix configuration (e.g., private S3 caches with authentication).

**Solution:** Disable `devenv`'s cache management:
```nix
# devenv.nix
{
  cachix.enable = false;
}
```

### Issue: `inputsFrom` doesn't propagate env vars or build deps reliably

**Problem:** In `mkShell`, `inputsFrom` inherits `buildInputs`/`nativeBuildInputs` from a derivation. In `devenv`, this doesn't reliably add packages to PATH or propagate environment variables (`PKG_CONFIG_PATH`, `LIBCLANG_PATH`).

**Solution:** Be explicit — list the packages and env vars you need in `devenv.nix`. Use the Phase 3 pattern (outputs in `devenv.nix`, extraction in `flake.nix`) to keep everything in one place.

### Issue: `buildRustPackage` needs `PKG_CONFIG_PATH` and `LIBCLANG_PATH`

**Problem:** Rust projects with `buildRustPackage` that use sys crates (nix-bindings-sys, openssl-sys) need these env vars set at both build time and dev time.

**Solution:** Set them in both places:
```nix
# In buildRustPackage
PKG_CONFIG_PATH = "${pkgs.nix.dev}/lib/pkgconfig";
LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";

# In devenv.nix shell env (for cargo build in dev shell)
env.PKG_CONFIG_PATH = "${pkgs.nix.dev}/lib/pkgconfig";
env.LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
```

### Issue: `container-processes` package needs `nix2container` input

**Problem:** `devenv` generates a `container-processes` package by default, which requires `nix2container` as a flake input, even if the project doesn't use containers.

**Solution:** Add to `flake.nix`:
```nix
inputs.nix2container.url = "github:nlewo/nix2container";
nix2container.inputs.nixpkgs.follows = "nixpkgs";
```

### Issue: `.pre-commit-config.yaml` is auto-generated

**Problem:** `devenv` generates this file from `git-hooks.hooks` config in `devenv.nix`. Committing it causes confusion when it's regenerated.

**Solution:** Add to `.gitignore`:
```gitignore
.pre-commit-config.yaml
```

### Issue: `devenv` CLI needs explicit input registration

**Problem:** Using `languages.rust`, `git-hooks.hooks`, etc. in `devenv.nix` requires the corresponding flake inputs to be registered with `devenv`.

**Solution:** Run these commands after adding language/hook config:
```bash
devenv inputs add rust-overlay github:oxalica/rust-overlay --follows nixpkgs
devenv inputs add git-hooks github:cachix/git-hooks.nix --follows nixpkgs
```

### Issue: `buildRustPackage` vs `crane` tradeoff

**Note:** `buildRustPackage` (built into nixpkgs) is simpler and needs no extra tool, but every dep change triggers a full rebuild. `crane` (from `github:ipetkov/crane`) gives incremental dep compilation at the cost of a separate tool and config split.

Choose based on how often your Rust dependencies change. For most projects, `buildRustPackage` is sufficient.

### Issue: `devenv: command not found`

**Solution:** Install devenv:

```bash
nix profile install github:cachix/devenv/latest
```

Or use via nix develop:

```bash
nix develop  # Still works, devenv is integrated into flake outputs
```

---

## Migration Checklist

- [ ] Identify project type
- [ ] Update `flake.nix` inputs (add flake-parts, devenv; remove flake-utils)
- [ ] Add `nixConfig` for devenv cachix
- [ ] Restructure `flake.nix` outputs to use `flake-parts.lib.mkFlake`
- [ ] Create `devenv.nix` with appropriate language/services
- [ ] Install latest devenv: `nix profile install github:cachix/devenv/latest`
- [ ] Install `use_devenv` direnv function -> `~/.config/direnv/lib/devenv.sh`
- [ ] Register devenv inputs: `devenv inputs add <name> <url> --follows nixpkgs`
- [ ] Add `nix2container` input to flake.nix (required by devenv internally)
- [ ] Set `cachix.enable = false` if you have system-level cache config
- [ ] Build from devenv: `nix build .#packages.<system>.default`
- [ ] Update `.gitignore` (add `.devenv/`, `.pre-commit-config.yaml`)
- [ ] Update `AGENTS.md` with new commands
- [ ] Run `nix flake update`
- [ ] Run `nix flake check`
- [ ] Run `devenv shell` and verify tools work
- [ ] Run `devenv test` and verify tests pass
- [ ] Run `nix build` and verify package builds
