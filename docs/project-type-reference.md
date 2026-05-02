# Project Type Reference

Quick reference for each project type's flake pattern, inputs, and outputs.

## 1. Python (uv2nix)

**Inputs:** `nixpkgs`, `flake-utils`, `uv2nix`, `pyproject-nix`
**Builder:** `pythonSet.mkVirtualEnv`
**Key files:** `pyproject.toml`, `uv.lock`, `flake.nix`

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    uv2nix.url = "github:adisbladis/uv2nix";
    pyproject-nix.url = "github:adisbladis/pyproject.nix";
  };

  outputs = { self, nixpkgs, flake-utils, uv2nix, pyproject-nix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };
        overlay = workspace.mkPyprojectOverlay { sourcePreference = "wheel"; };
        pythonSet = pkgs.callPackage pyproject-nix.build.packages {
          python = pkgs.python3;
        }.overrideScope [ overlay ];
      in {
        packages.default = pythonSet.mkVirtualEnv "my-app-env" { };
        devShells.default = pkgs.mkShell {
          inputsFrom = [ self.packages.${system}.default ];
          packages = with pkgs; [ uv ];
        };
      }
    );
}
```

## 2. Rust (crane)

**Inputs:** `nixpkgs`, `flake-utils`, `crane`
**Builder:** `craneLib.buildPackage` (split: `buildDepsOnly` + `buildPackage`)
**Key files:** `Cargo.toml`, `Cargo.lock`, `flake.nix`

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    crane.url = "github:ipetkov/crane";
  };
  # ...craneLib, cargoArtifacts = buildDepsOnly, buildPackage { inherit cargoArtifacts; }
}
```

**Sys crate handling:**
```nix
craneLib.buildPackage {
  src = craneLib.cleanCargoSource ./.;
  nativeBuildInputs = [ pkgs.pkg-config ];
  buildInputs = [ pkgs.openssl ];
}
```

## 3. Go

**Inputs:** `nixpkgs`, `flake-utils`
**Builder:** `buildGoModule`
**Key files:** `go.mod`, `go.sum`, `flake.nix`

```nix
packages.default = pkgs.buildGoModule {
  pname = "my-app";
  version = "0.1.0";
  src = ./.;
  vendorHash = "sha256-...";  # Set after first build
  subPackages = [ "." ];
};
```

**To get vendorHash:** Set to `""`, run `nix build`, copy the hash from the error.

## 4. Node/JS

**Inputs:** `nixpkgs`, `flake-utils`
**Builder:** `buildNpmPackage`
**Key files:** `package.json`, `package-lock.json`, `flake.nix`

```nix
packages.default = pkgs.buildNpmPackage {
  pname = "my-app";
  version = "0.1.0";
  src = ./.;
  npmDepsHash = "sha256-...";  # Set after first build
  buildPhase = "npm run build";
  installPhase = "cp -r dist $out";
};
```

**To get npmDepsHash:** Set to `""`, run `nix build`, copy the hash from the error.

## 5. Embedded (ESP-IDF / Arduino)

**Inputs:** `nixpkgs`, `flake-utils`, `esp-dev`, `(optional) arduino-nix`
**Builder:** `stdenv.mkDerivation` with ESP-IDF toolchain
**Key files:** `CMakeLists.txt`, `flake.nix`, `nix/scripts.nix`, `nix/dependencies.nix`

**Structure:**
- `flake.nix`: Exports packages (firmware, tests) + devShell via `esp-dev.devShells`
- `nix/scripts.nix`: Wrapper scripts (build-firmware, flash, monitor, ci-ready)
- `nix/dependencies.nix`: Vendored managed components
- `treefmt.toml`: C++ formatting via clang-format

**CI considerations:**
- May need AppArmor workaround for bubblewrap
- Build artifacts: `.bin`, `.elf`, partitions, bootloader
- Nightly releases for firmware binaries

## 6. Container (Nix-built OCI)

**Inputs:** `nixpkgs`, `flake-utils`, `(optional) ops-utils`
**Builder:** `dockerTools.buildImage` / `streamLayeredImage`
**Key files:** `flake.nix`

```nix
packages.default = pkgs.dockerTools.buildImage {
  name = "my-image";
  tag = "latest";
  config.Cmd = [ "${pkgs.my-app}/bin/my-app" ];
};
```

**Multi-arch push:** Use `ops-utils`:
```nix
packages.push-multi-arch = ops-utils.lib.mkPushMultiArch {
  inherit pkgs;
  supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
};
```

## 7. Dev Shell Only

**Inputs:** `nixpkgs`, `flake-utils`
**Builder:** `mkShell` (no package derivation)
**Key files:** `flake.nix`

```nix
devShells.default = pkgs.mkShell {
  packages = with pkgs; [ tool1 tool2 ];
  shellHook = ''
    echo "Commands available: ..."
  '';
};
```

**No `packages.default`**, no `checks.tests` (but `checks.formatting` can still exist).

## 8. Nix Library

**Inputs:** `nixpkgs` (minimal)
**Outputs:** `lib` (not `packages`)
**Key files:** `flake.nix`, `lib/*.nix`

```nix
outputs = { self, nixpkgs }: {
  lib = {
    mkMyUtil = import ./lib/my-util.nix;
    mkUtils = { pkgs }: {
      my-util = mkMyUtil { inherit pkgs; };
    };
    mkApps = { pkgs }: utils:
      pkgs.lib.mapAttrs (name: pkg: {
        type = "app";
        program = "${pkg}/bin/${name}";
      }) utils;
  };
};
```

## 9. NixOS Configuration

**Inputs:** `nixpkgs`, `flake-utils`, `(various)`
**Builder:** `nixosSystem`
**Key files:** `flake.nix`, `systems/`, `modules/`, `overlays/`

```nix
outputs = { self, nixpkgs, ... }: {
  nixosConfigurations = {
    my-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        ./modules/networking.nix
      ];
    };
  };
};
```
