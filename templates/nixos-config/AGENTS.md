# Agent Working Guide — NixOS Configuration

## Environment

NixOS system configuration managed via flake. Supports declarative system configuration with modules.

## Structure

```
flake.nix              # Entry point — defines hosts
configuration.nix      # Main system config for a host
modules/
  networking.nix       # Networking config
  services.nix         # Service configs
```

## Available Commands

| Command | Description |
|---------|-------------|
| `nix develop` | Enter dev shell |
| `sudo nixos-rebuild switch --flake .#my-host` | Apply config |
| `nix build .#nixosConfigurations.my-host.config.system.build.toplevel` | Build without applying |

## Mandatory Pre-Submission

```bash
nix develop --command agent-check
```

## Important Notes

- Secrets should use `sops-nix` — never commit plaintext secrets
- Hardware configs from `nixos-hardware` for known machines
- Use `disko` for declarative disk partitioning
- Each host gets its own module in `nixosConfigurations`
