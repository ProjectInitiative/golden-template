
## Common Pitfalls (from real migrations)

1. **`inputsFrom` doesn't propagate env vars** in devenv — always set `PKG_CONFIG_PATH`, `LIBCLANG_PATH` etc. explicitly in `devenv.nix` `env`. Don't rely on `inputsFrom` for them.

2. **`container-processes` requires `nix2container`** — you need this flake input even if you don't use containers. Add it to `flake.nix`.

3. **`cachix.enable = false`** — set this in `devenv.nix` if the user's system nix daemon already manages caches. Otherwise `devenv` will try and fail with auth errors. This should be the default for most projects.

4. **`devenv.root` causes read-only filesystem errors** — with `use devenv` (2.x) + direnv, setting `devenv.root = toString ./.` in `flake.nix` forces the path to the Nix store copy (read-only). Remove it from `flake.nix`; devenv 2.x detects the project root at runtime via `direnv-export`.

5. **Sys crates need build env vars** — `nix-bindings-sys`, `openssl-sys`, etc. need `PKG_CONFIG_PATH` and `LIBCLANG_PATH` at both build time and dev time. Set them in both `buildRustPackage` and `devenv.nix env`.

6. **`.pre-commit-config.yaml` is auto-generated** — gitignore it, don't commit it.

7. **`nix path-info --json` uses base64** — the narHash field is `"sha256-<base64>"` not `"sha256:<base32>"`. Make sure your hash parser handles both formats.

8. **`enterShell` belongs in `devenv.nix`, not `flake.nix`** — put `enterShell` as a top-level attribute in `devenv.nix`. When `enterShell` is in `flake.nix` under `devenv.shells.default`, direnv may suppress its output. The `devenv.nix` location matches the standard pattern (see `loft`, `rust-crane` template).

9. **`.envrc` should be just `use devenv`** — don't add extra `echo` commands or logic. All shell setup (welcome messages, pre-commit hooks, PATH additions) goes in `devenv.nix` `enterShell`.

10. **`git-hooks` module requires `devenv inputs add`** — adding `git-hooks` as a `flake.nix` input is NOT sufficient. The `devenv` CLI requires it registered via `devenv inputs add git-hooks github:cachix/git-hooks.nix --follows nixpkgs`. If `devenv` can't write (read-only store), skip `git-hooks` and install hooks manually in `enterShell`.

11. **`mk-shell-bin` input is required** — `devenv` auto-generates `container-shell` which needs this input. Add `mk-shell-bin.url = "github:rrbutani/nix-mk-shell-bin"` to `flake.nix` inputs even if you don't use shells-as-binaries.

12. **`container-*` auto-generated packages may fail on new nixpkgs** — `nodePackages` was removed from nixpkgs (migrated to top-level `pkgs.*`). Affects `container-processes` and `container-shell`. Fix: use `pkgs.prettier` instead of `pkgs.nodePackages.prettier`, and avoid `nodePackages` anywhere in `mkShell` or devenv `packages`. If unavoidable, suppress the container packages with `pkgs.lib.mkForce pkgs.emptyDirectory` in `flake.nix`.
