# Agent Working Guide — Embedded Firmware Project

## Environment

ESP-IDF development environment managed by Nix via `esp-dev`. Arduino libraries via `arduino-nix` if applicable.

## Available Commands

| Command | Description |
|---------|-------------|
| `build-firmware` | Build firmware via idf.py |
| `upload-firmware` | Upload via serial or OTA |
| `monitor-firmware` | Monitor serial logs |
| `ci-ready` | Run formatting + tests + build |
| `treefmt` | Format all code |

## Mandatory Pre-Submission

```bash
nix develop --command agent-check
```

## Important Notes

- ESP-IDF uses bubblewrap internally; CI may need AppArmor workaround
- All managed components must be vendored in `nix/dependencies.nix`
- Firmware binaries are CI artifacts — use `nix build` for sandboxed verification
