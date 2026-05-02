# Agent Working Guide — Nix Library

## Environment

This flake exposes reusable Nix functions via `lib`. It does not produce packages.

## Structure

```
lib/
  my-util.nix     # Individual function module
flake.nix         # Exposes lib + devShell
```

## Available Commands

| Command | Description |
|---------|-------------|
| `nix develop` | Enter dev shell |
| `nix flake check` | Verify formatting |

## Adding a New Function

1. Create `lib/<function-name>.nix`
2. Import it in `flake.nix` under `lib`
3. Add to `mkUtils` convenience function
4. Document the function signature in README

## Conventions

- Each function should take a single attrset argument with `{ pkgs, ... }`
- Functions return a derivation (via `writeShellScriptBin` or similar)
- Provide a `mkUtils` helper that instantiates all functions at once
- Provide a `mkApps` helper that generates flake app entries from utils
