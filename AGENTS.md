
## Common Pitfalls (from real migrations)

1. **`inputsFrom` doesn't propagate env vars** in devenv — always set `PKG_CONFIG_PATH`, `LIBCLANG_PATH` etc. explicitly in `devenv.nix` `env`. Don't rely on `inputsFrom` for them.

2. **`container-processes` requires `nix2container`** — you need this flake input even if you don't use containers. Add it to `flake.nix`.

3. **`cachix.enable = false`** — set this if the user's system nix daemon already manages caches. Otherwise `devenv` will try and fail with auth errors.

4. **`devenv root` / read-only filesystem** — with `devenv` 1.x + `use flake`, `devenv.root` resolves to the nix store path (read-only). Fix by upgrading to `devenv` 2.x and using `use devenv` (not `use flake`).

5. **Sys crates need build env vars** — `nix-bindings-sys`, `openssl-sys`, etc. need `PKG_CONFIG_PATH` and `LIBCLANG_PATH` at both build time and dev time. Set them in both `buildRustPackage` and `devenv.nix env`.

6. **`.pre-commit-config.yaml` is auto-generated** — gitignore it, don't commit it.

7. **`nix path-info --json` uses base64** — the narHash field is `"sha256-<base64>"` not `"sha256:<base32>"`. Make sure your hash parser handles both formats.
