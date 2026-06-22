# Devenv Integration Plan for Golden Template

## Executive Summary

This plan migrates the golden-template repository from raw `flake-utils` + manual `mkShell` definitions to a **devenv-powered architecture** that provides:

1. **Unified configuration** - Single source of truth for dev shells, packages, and containers
2. **Language abstractions** - 57 pre-built language modules with LSP, tooling, and auto-dependencies
3. **Service management** - 42 service modules (postgres, redis, kafka, etc.) with `devenv up`
4. **Process orchestration** - Built-in process manager for background services
5. **Task system** - DAG-based task execution with caching
6. **Reduced boilerplate** - Eliminate manual shellHook plumbing and dependency duplication

---

## Current State Analysis

### What We Have Now

```
templates/
├── python-uv2nix/flake.nix      # Manual mkShell, shellHook, uv setup
├── rust-crane/flake.nix         # Manual fenix toolchain, crane config
├── go/flake.nix                 # Manual gopls, delve, gotools
├── node-js/flake.nix            # Manual nodejs, typescript setup
├── dev-shell/flake.nix          # Basic mkShell with tool list
├── container/flake.nix          # dockerTools patterns
└── ... (12 templates total)
```

**Pain Points:**

- Manual tool lists in every template (gopls, rust-analyzer, typescript-language-server, etc.)
- No service abstractions (postgres, redis require manual shellHook scripts)
- No process management (background services need manual terminal splits)
- Duplicated boilerplate across templates
- No unified package/shell/container definitions

### What Devenv Provides

```
devenv modules:
├── languages/ (57 modules)
│   ├── python.nix    # venv, uv, poetry, pyright LSP
│   ├── rust.nix      # toolchain, rust-analyzer, mold linker
│   ├── go.nix        # gopls, delve, gotools (all version-matched)
│   ├── javascript.nix # npm/pnpm/yarn/bun, auto-install, tsserver
│   └── ...
├── services/ (42 modules)
│   ├── postgres.nix  # extensions, initial DBs, readiness probes
│   ├── redis.nix     # TCP/unix socket, configurable bind
│   ├── kafka.nix     # KRaft/Zookeeper modes
│   └── ...
├── integrations/ (15 modules)
│   ├── git-hooks.nix # pre-commit hooks
│   ├── treefmt.nix   # formatter integration
│   └── ...
└── process-managers/ (6 modules)
    ├── native.nix    # devenv's built-in manager
    ├── process-compose.nix
    └── ...
```

---

## Migration Strategy

### Phase 1: Infrastructure Setup

#### 1.1 Update Root `flake.nix` to Use flake-parts + devenv

**Current:**

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system: ...);
}
```

**Target:**

```nix
{
  description = "ProjectInitiative Golden Template";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
  };

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.devenv.flakeModule
      ];
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      perSystem = { config, self', inputs', pkgs, system, ... }: {
        # Root dev shell for template development
        devenv.shells.default = {
          name = "golden-template";
          cachix.enable = false;

          packages = with pkgs; [
            nixfmt
            treefmt
            just
            mdbook
          ];

          languages.nix.enable = true;

          enterShell = ''
            echo "Golden Template Dev Shell"
            echo "Commands: validate-templates, agent-check"
          '';

          scripts.validate-templates.exec = builtins.readFile ./nix/validate-templates.sh;
          scripts.agent-check.exec = ''
            set -euo pipefail
            echo "=== Agent Pre-Submission Check ==="
            # ... check logic
          '';
        };

        packages.validate-templates = config.devenv.shells.default.scripts.validate-templates.package;
        packages.agent-check = config.devenv.shells.default.scripts.agent-check.package;

        checks.formatting = pkgs.runCommand "check-formatting" { } ''
          # ... formatting check
        '';

        formatter = pkgs.nixfmt;
      };

      flake = {
        templates = {
          # ... template definitions (unchanged structure)
        };
      };
    };
}
```

**Benefits:**

- Cleaner output structure via flake-parts
- devenv integration for root dev shell
- Scripts become first-class citizens (exposed in PATH)
- Better multi-system support

> **Caution — `devenv.root` in devenv 2.x:**
>
> Do NOT set `devenv.root = toString ./.` in `flake.nix` when using devenv 2.x
> with `use devenv` in `.envrc`. Devenv 2.x auto-detects the project root at
> runtime via `direnv-export`. Setting it explicitly resolves to a read-only Nix
> store path at evaluation time and will cause filesystem errors.
>
> **Note — `enterShell` location:**
>
> For projects that use a separate `devenv.nix` file (recommended), place
> `enterShell` as a top-level attribute in `devenv.nix` rather than nesting it
> inside `devenv.shells.default` in `flake.nix`. The `devenv.nix` location
> ensures the welcome message prints reliably; when placed in `flake.nix`,
> direnv may suppress `enterShell` output.

---

### Phase 2: Template Conversions

#### 2.1 Python Template (python-uv2nix)

**Current `flake.nix` (103 lines):**

- Manual uv2nix workspace loading
- Manual overlay creation
- Manual mkShell with tool list
- Manual shellHook for echo statements

**Target `devenv.nix` + `flake.nix`:**

```nix
# devenv.nix
{ pkgs, config, ... }: {
  cachix.enable = false;

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
    echo "Python dev environment (uv2nix + devenv)"
    echo "Commands: uv run pytest, uv add <pkg>, uv lock"
  '';

  # Pre-commit hooks
  git-hooks.hooks = {
    ruff.enable = true;
    nixfmt-rfc-style.enable = true;
  };

  # Test integration
  enterTest = ''
    uv run pytest tests/
  '';
}
```

```nix
# flake.nix (simplified)
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devenv.url = "github:cachix/devenv";
    uv2nix.url = "github:adisbladis/uv2nix";
    pyproject-nix.url = "github:adisbladis/pyproject.nix";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.devenv.flakeModule ];
      systems = [ "x86_64-linux" "aarch64-linux" ];

      perSystem = { config, pkgs, ... }: {
        # Package build (unchanged uv2nix logic)
        packages.default = /* ... uv2nix build ... */;

        # Dev shell via devenv
        devenv.shells.default = {
          imports = [ ./devenv.nix ];
          packages = [ config.packages.default ];
        };
      };
    };
}
```

**Benefits:**

- `languages.python` auto-configures venv, uv, pyright LSP
- `git-hooks` integration for pre-commit
- `enterTest` for unified test execution
- Reduced from 103 lines to ~40 lines

---

#### 2.2 Rust Template (rust-crane)

**Target `devenv.nix`:**

```nix
{ pkgs, ... }: {
  cachix.enable = false;

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
    echo "Rust dev environment (crane + devenv)"
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

**Benefits:**

- `languages.rust` auto-configures toolchain, rust-analyzer, optional mold linker
- Auto-enables C language for sys crates
- Crane build logic remains in `flake.nix` for production builds

---

#### 2.3 Go Template

**Target `devenv.nix`:**

```nix
{ pkgs, ... }: {
  cachix.enable = false;

  languages.go = {
    enable = true;
    package = pkgs.go_1_22;  # Version pinning
  };

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

**Benefits:**

- `languages.go` provides gopls, delve, gotools (all version-matched to go package)
- No manual tool list maintenance

---

#### 2.4 Node.js Template

**Target `devenv.nix`:**

```nix
{ pkgs, ... }: {
  cachix.enable = false;

  languages.javascript = {
    enable = true;
    package = pkgs.nodejs_22;
    npm.install.enable = true;  // Auto-install on shell entry
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

**Benefits:**

- `languages.javascript` supports npm/pnpm/yarn/bun
- Auto-installs dependencies on shell entry (with checksum caching)
- typescript-language-server auto-configured

---

#### 2.5 Dev Shell Template (Enhanced with Services)

**Target `devenv.nix`:**

```nix
{ pkgs, ... }: {
  cachix.enable = false;

  packages = with pkgs; [
    jq
    yq
    ripgrep
    fd
  ];

  # Add services as needed
  services.postgres = {
    enable = true;
    initialDatabases = [{ name = "app_dev"; }];
  };

  services.redis.enable = true;

  enterShell = ''
    echo "Dev shell with services"
    echo "Run 'devenv up' to start postgres + redis"
  '';
}
```

**Benefits:**

- `devenv up` starts postgres + redis with proper ordering
- Readiness probes ensure DB is ready before shell entry
- No manual shellHook scripts for service management

---

#### 2.6 Container Template (Unified with devenv)

**Target `devenv.nix`:**

```nix
{ pkgs, config, ... }: {
  cachix.enable = false;

  packages = with pkgs; [
    docker
    skopeo
  ];

  # Define container using devenv's container module
  containers.my-app = {
    name = "my-app";
    version = "latest";
    copyToRoot = [ config.packages.default ];
    startupCommand = [ "${config.packages.default}/bin/my-app" ];
  };

  enterShell = ''
    echo "Container build environment"
    echo "Commands:"
    echo "  devenv container build my-app"
    echo "  nix build .#default"
  '';
}
```

**Benefits:**

- `devenv container build` command for OCI images
- Unified package/container definitions
- Same derivation used in dev shell and production container

---

### Phase 3: Advanced Patterns

#### 3.1 Unified Package + Shell + Module Definition

For projects that export NixOS modules (like your `loft` tool):

```nix
# devenv.nix
{ pkgs, lib, config, ... }: {
  cachix.enable = false;

  # Project metadata
  options.loftProject = {
    version = lib.mkOption { type = lib.types.str; default = "0.1.0"; };
    s3TargetDir = lib.mkOption { type = lib.types.str; default = "/closures"; };
  };

  config = {
    # Dev environment
    languages.rust.enable = true;
    packages = [ pkgs.openssl pkgs.pkg-config ];

    # Package build
    outputs.loft = pkgs.rustPlatform.buildRustPackage {
      pname = "loft";
      version = config.loftProject.version;
      src = ./.;
      # ... build config
    };

    # Container build
    containers.loft-daemon = {
      name = "loft-uploader";
      version = config.loftProject.version;
      startupCommand = [ "${config.outputs.loft}/bin/loft" "--target" config.loftProject.s3TargetDir ];
      copyToRoot = [ pkgs.cacert pkgs.openssl ];
    };
  };
}
```

```nix
# flake.nix
{
  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.devenv.flakeModule ];

      perSystem = { config, ... }: {
        devenv.shells.default = {
          imports = [ ./devenv.nix ];
        };

        # Extract package from devenv
        packages.default = config.devenv.shells.default.outputs.loft;
      };

      # Export NixOS module
      flake.nixosModules.loft = { config, lib, pkgs, ... }: {
        options.services.loft = {
          enable = lib.mkEnableOption "Loft Service";
          package = lib.mkOption {
            type = lib.types.package;
            default = pkgs.loft;  # References devenv-built package
          };
        };
        # ... systemd config
      };
    };
}
```

**Benefits:**

- Single source of truth for version, paths, dependencies
- Package built by devenv is used in dev shell, container, and NixOS module
- No duplication between shell and module definitions

---

#### 3.2 Service-Heavy Development (Full Stack App)

```nix
# devenv.nix
{ pkgs, ... }: {
  cachix.enable = false;

  languages = {
    javascript.enable = true;
    typescript.enable = true;
  };

  services = {
    postgres = {
      enable = true;
      initialDatabases = [{ name = "myapp"; }];
      initialScript = ''
        CREATE USER myapp WITH PASSWORD 'dev';
        GRANT ALL PRIVILEGES ON DATABASE myapp TO myapp;
      '';
    };

    redis.enable = true;

    minio = {
      enable = true;
      buckets = ["uploads" "avatars"];
    };
  };

  processes = {
    api.exec = "npm run dev:api";
    worker.exec = "npm run dev:worker";
  };

  enterShell = ''
    echo "Full-stack dev environment"
    echo "Run 'devenv up' to start all services + processes"
  '';
}
```

**Benefits:**

- `devenv up` starts postgres, redis, minio, api, worker in parallel
- Proper dependency ordering (DB ready before API starts)
- One command to spin up entire dev environment

---

### 3.3 Phase 3 Pattern (Final): Everything in `devenv.nix`

> **Note:** Phase 3 eliminates the split between `flake.nix` (build) and `devenv.nix` (dev) by moving build definitions into `devenv.nix` via `outputs.<name>`.

This is the pattern we settled on after the loft migration. It provides single-source-of-truth for all dependencies:

```nix
# devenv.nix - single source for everything
{ pkgs, config, ... }: {
  cachix.enable = false;

  languages.rust.enable = true;     # Language tooling (also used by build)

  packages = with pkgs; [ ... ];    # Dev-only tools

  outputs.app = pkgs.rustPlatform.buildRustPackage {   # The build itself
    pname = "my-app";
    version = "0.1.0";
    src = ./.;
    buildInputs = with pkgs; [ ... ];
    nativeBuildInputs = with pkgs; [ ... ];
  };

  env.PKG_CONFIG_PATH = "${pkgs.nix.dev}/lib/pkgconfig";  # Build env vars
  env.LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
}
```

```nix
# flake.nix - just wiring
perSystem = { config, ... }: {
  packages.default = config.devenv.shells.default.outputs.app;  # Extract
  devenv.shells.default = { imports = [ ./devenv.nix ]; };
};
```

**Benefits:**
- One file for build, dev, languages, env vars, git hooks
- No `inputsFrom` needed (env vars and packages are explicit)
- Works cleanly with `use devenv` (devenv 2.x required)

**Drawbacks:**
- `buildRustPackage` means full rebuild on dep changes (vs crane's incremental)
- Workspace/CLI tools need to be duplicated if also needed in build phase

---

### Phase 4: Documentation Updates

#### 4.1 Update AGENTS.md

Add devenv-specific commands:

````markdown
## Available Commands

| Command                         | Description                    |
| ------------------------------- | ------------------------------ |
| `devenv shell`                  | Enter dev shell                |
| `devenv up`                     | Start all services + processes |
| `devenv test`                   | Run test suite                 |
| `devenv container build <name>` | Build OCI container            |
| `nix build`                     | Full sandboxed build           |

## Services

This project includes the following services (started via `devenv up`):

- **postgres** - PostgreSQL database (port 5432)
- **redis** - Redis cache (port 6379)

## Adding a New Service

Edit `devenv.nix` and add:

```nix
services.<name>.enable = true;
```
````

See https://devenv.sh/reference/options/#services for available services.

````

#### 4.2 Update DESIGN.md

Document the devenv integration rationale:

```markdown
## Why Devenv?

1. **Language Abstractions** - No manual tool lists (gopls, rust-analyzer, etc.)
2. **Service Management** - `devenv up` for postgres, redis, kafka, etc.
3. **Process Orchestration** - Built-in process manager for background tasks
4. **Unified Configuration** - Single source of truth for shell, package, container
5. **Reduced Boilerplate** - Eliminate shellHook plumbing and dependency duplication

## Architecture

````

flake.nix (flake-parts + devenv.flakeModule)
↓
devenv.nix (languages, services, processes, git-hooks)
↓
├── devShells.default (via devenv.shells.default)
├── packages.default (via outputs.<name>)
└── containers.<name> (via containers.<name>)

```

```

---

## Migration Checklist

### Phase 1: Infrastructure

- [ ] Update root `flake.nix` to use flake-parts + devenv
- [ ] Add devenv cachix to nixConfig
- [ ] Convert root devShell to devenv.shells.default
- [ ] Test `nix flake check` passes

### Phase 2: Template Conversions

- [ ] python-uv2nix: Create devenv.nix, simplify flake.nix
- [ ] rust-crane: Create devenv.nix, simplify flake.nix
- [ ] go: Create devenv.nix, simplify flake.nix
- [ ] node-js: Create devenv.nix, simplify flake.nix
- [ ] dev-shell: Add service examples
- [ ] container: Add devenv container module
- [ ] Test each template: `nix flake init -t .#<name> && nix flake check`

### Phase 3: Advanced Patterns

- [ ] Create unified package/shell/module example
- [ ] Create service-heavy full-stack example
- [ ] Document patterns in docs/

### Phase 4: Documentation

- [ ] Update AGENTS.md with devenv commands
- [ ] Update DESIGN.md with architecture rationale
- [ ] Update README.md with devenv benefits
- [ ] Add migration guide for existing projects

---

## Comparison: Before vs After

### Python Template

| Metric             | Before                   | After                          | Improvement |
| ------------------ | ------------------------ | ------------------------------ | ----------- |
| Lines of code      | 103                      | ~60                            | -42%        |
| Manual tool list   | Yes (pytest, ruff, mypy) | No (auto via languages.python) | Eliminated  |
| Service support    | No                       | Yes (services.postgres, etc.)  | Added       |
| Process management | No                       | Yes (devenv up)                | Added       |
| Git hooks          | Manual                   | Yes (git-hooks.hooks)          | Simplified  |
| LSP setup          | Manual                   | Auto (pyright)                 | Eliminated  |

### Rust Template

| Metric                    | Before         | After                 | Improvement |
| ------------------------- | -------------- | --------------------- | ----------- |
| Lines of code             | 87             | ~50                   | -43%        |
| Toolchain setup           | Manual (fenix) | Auto (languages.rust) | Simplified  |
| rust-analyzer             | Manual         | Auto                  | Eliminated  |
| C language for sys crates | Manual         | Auto-enabled          | Eliminated  |
| Git hooks                 | Manual         | Yes (rustfmt, clippy) | Simplified  |

---

## Risk Mitigation

### Risk: Breaking Existing Templates

**Mitigation:**

- Keep old templates as `*-legacy` during transition
- Test each template with `nix flake init` + `nix flake check`
- Validate with `validate-templates` script

### Risk: Devenv Learning Curve

**Mitigation:**

- Provide side-by-side comparison in MIGRATION_GUIDE.md
- Include examples for common patterns
- Link to devenv.sh documentation

### Risk: flake-parts Complexity

**Mitigation:**

- Start with simple templates (dev-shell, go)
- Gradually introduce advanced patterns
- Provide "flake-parts vs flake-utils" comparison doc

---

## Success Criteria

1. All 12 templates converted to use devenv
2. Root flake.nix uses flake-parts + devenv.flakeModule
3. `nix flake check` passes for all templates
4. `validate-templates` script passes
5. Documentation updated (AGENTS.md, DESIGN.md, README.md)
6. At least one advanced pattern example (unified package/shell/module)
7. Migration guide for existing projects

---

## Next Steps

1. **Start with Phase 1** - Update root flake.nix
2. **Pick one simple template** (go or dev-shell) to convert first
3. **Test thoroughly** before proceeding to other templates
4. **Document as you go** - Update AGENTS.md for each template
5. **Create examples** - Show unified package/shell/module pattern
6. **Validate** - Run `nix flake check && nix build` on all templates

---

## References

- [devenv.sh documentation](https://devenv.sh/)
- [devenv language modules](https://devenv.sh/reference/options/#languages)
- [devenv services](https://devenv.sh/reference/options/#services)
- [flake-parts documentation](https://flake.parts/)
- [devenv + flake-parts guide](https://devenv.sh/guides/using-with-flake-parts/)
