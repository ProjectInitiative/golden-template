# Agent Working Guide — Node.js Project

## Environment

Node.js project built with `buildNpmPackage`.

## Available Commands

| Command                               | Description          |
| ------------------------------------- | -------------------- |
| `nix develop --command npm run dev`   | Dev server           |
| `nix develop --command npm test`      | Run tests            |
| `nix develop --command npm run build` | Build                |
| `nix build`                           | Full sandboxed build |

## Mandatory Pre-Submission

```bash
nix develop --command agent-check
```

## Adding a Dependency

1. `nix develop --command npm install <package>`
2. Update `npmDepsHash` in `flake.nix` by setting to `""`, building, and copying the hash
