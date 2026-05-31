# Agent Working Guide — Dev Shell Only

## Environment

This project uses **devenv** to provide a Nix development shell with tools but does not produce a build artifact.

## Available Commands

| Command           | Description       |
| ----------------- | ----------------- |
| `devenv shell`    | Enter dev shell   |
| `devenv test`     | Run tests         |
| `nix flake check` | Verify formatting |

## Important Notes

- No `packages.default` — this is intentional
- No `tests` check — there are no unit tests for a tool shell
- Add/remove tools in `devenv.nix` under `packages`
