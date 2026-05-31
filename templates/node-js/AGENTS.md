# Agent Working Guide — Node.js Project

## Environment

This project uses **devenv** for the development environment. Node.js project built with `buildNpmPackage` for sandboxed Nix builds. The dev shell is loaded automatically via `direnv`.

## Available Commands

| Command                         | Description          |
| ------------------------------- | -------------------- |
| `devenv shell -- npm run dev`   | Dev server           |
| `devenv shell -- npm test`      | Run tests            |
| `devenv shell -- npm run build` | Build                |
| `devenv test`                   | Run test suite       |
| `nix build`                     | Full sandboxed build |

## Mandatory Pre-Submission

```bash
nix develop --command agent-check
```

## Adding a Dependency

1. `devenv shell -- npm install <package>`
2. Update `npmDepsHash` in `flake.nix` by setting to `""`, building, and copying the hash
