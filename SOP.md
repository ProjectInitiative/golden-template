# Standard Operating Procedures — Nix Project Lifecycle

## 1. Bootstrapping a New Project

```bash
# 1. Create repo and clone
mkdir my-project && cd my-project && git init

# 2. Scaffold from template
nix flake init -t github:projectinitiative/golden-template#python

# 3. Allow direnv
direnv allow

# 4. Generate lockfile
nix flake lock

# 5. Verify
nix flake check && nix build

# 6. Initial commit
git add -A && git commit -m "Initial scaffold from golden-template"
```

## 2. Converting an Existing Project to Nix

See `MIGRATION_GUIDE.md` for detailed steps.

High-level process:

1. **Analyze**: Identify build system, runtime deps, test framework
2. **Scaffold**: Start from the closest template
3. **Populate**: Move dependencies from `package.json`/`Cargo.toml`/`pyproject.toml` into `flake.nix`
4. **Iterate**: Use `nix develop --command <build>` for fast iteration
5. **Verify**: Run `nix flake check && nix build`
6. **Document**: Update `AGENTS.md` and `DESIGN.md` with project-specific notes

## 3. CI Setup

Every project uses the same CI pattern:

```yaml
name: CI
on: [push, pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: DeterminateSystems/nix-installer-action@v10
      - run: nix flake check
  build:
    needs: check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: DeterminateSystems/nix-installer-action@v10
      - run: nix build
```

See `docs/ci-strategies.md` for alternatives and tradeoffs.

## 4. Dependency Updates

```bash
# Update all inputs
nix flake update

# Update a specific input
nix flake update nixpkgs

# Check for outdated inputs
nix flake metadata
```

## 5. Adding a New Template to This Repo

1. Create directory: `templates/<type>/`
2. Populate with: `flake.nix`, `.envrc`, `AGENTS.md`, `treefmt.toml`, `.github/workflows/ci.yml`
3. Register in root `flake.nix` under `templates`
4. Add entry to `docs/project-type-reference.md`
5. Run `nix flake check` on the template to verify validity

## 6. Release Checklist

- [ ] `nix flake check` passes
- [ ] `nix build` succeeds
- [ ] `AGENTS.md` is up to date
- [ ] `DESIGN.md` reflects current architecture
- [ ] CI is green on all supported platforms
- [ ] `treefmt` has been run
- [ ] No `TODO` or `FIXME` in production code
