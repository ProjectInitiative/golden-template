# CI Strategies for Nix Projects

## Comparison

| Approach | Action | Pros | Cons | Best For |
|----------|--------|------|------|----------|
| **DeterminateSystems** | `nix-installer-action@v10` | Handles flakes natively; detects config issues; built-in Magic Nix Cache | No fine-grained Nix config control | Most projects; the default |
| **cachix/install-nix-action** | `cachix/install-nix-action@v25` | Supports custom `nix.conf` via `extra_nix_config`; battle-tested | Older; requires manual flake setup | Projects needing custom Nix config |
| **Self-hosted runner** | Manual Nix install | Full control; air-gapped; no rate limits | Maintenance overhead | Air-gapped or custom runner environments |

## Recommendation

Use **DeterminateSystems/nix-installer-action** as the default for all new projects.

```yaml
- uses: DeterminateSystems/nix-installer-action@v10
  with:
    extra-conf: |
      accept-flake-config = true
```

Use **cachix/install-nix-action** when you need explicit control over Nix config options that the DeterminateSystems action doesn't expose.

```yaml
- uses: cachix/install-nix-action@v25
  with:
    nix_path: nixpkgs=channel:nixos-unstable
    extra_nix_config: |
      sandbox = false
      system-features = nixos-test benchmark big-parallel kvm
```

## Attic Cache Integration

For projects that need a shared binary cache (especially multi-arch builds):

```yaml
- name: Setup Attic
  run: |
    nix profile install nixpkgs#attic-client
    attic login ci $ATTIC_ENDPOINT $ATTIC_TOKEN
```

Then push to cache after builds:

```yaml
- name: Push to cache
  run: |
    nix build .#my-package --no-link
    attic push ci $(nix path-info .#my-package)
```

## Standard CI Pipeline

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

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

## Multi-Arch CI (Container Builds)

For container image projects that build for multiple architectures:

```yaml
- name: Install QEMU
  run: sudo apt-get update && sudo apt-get install -y qemu-user-static

- name: Configure Nix for QEMU
  run: |
    echo "extra-platforms = aarch64-linux" | sudo tee -a /etc/nix/nix.conf
    sudo systemctl restart nix-daemon
```

## Firmware/Embedded CI Notes

- **AppArmor + bwrap**: ESP-IDF builds use bubblewrap internally. See NIMRS-Firmware CI for AppArmor workaround.
- **Hardware flashing**: CI cannot flash real hardware. Expose firmware binaries as CI artifacts.
- **Nightly releases**: Use `softprops/action-gh-release` for automated releases.

## Caching Strategy

| Cache Type | Tool | Use Case |
|------------|------|----------|
| Magic Nix Cache | DeterminateSystems | Zero-config, ephemeral CI caching |
| Attic | self-hosted | Persistent cross-project cache |
| Cachix | SaaS | Simple per-project cache |
| GitHub Actions Cache | `nix-actions/cache` | Free, no external service |
