# Agent Working Guide — Dev Shell Only

## Environment

This project provides a Nix development shell with tools but does not produce a build artifact.

## Available Commands

| Command           | Description       |
| ----------------- | ----------------- |
| `nix develop`     | Enter dev shell   |
| `nix flake check` | Verify formatting |

## Important Notes

- No `packages.default` — this is intentional
- No `tests` check — there are no unit tests for a tool shell
- Add/remove tools in the `packages` list in `flake.nix`
