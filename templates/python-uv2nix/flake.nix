{
  description = "Python project managed with uv2nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    uv2nix.url = "github:adisbladis/uv2nix";
    pyproject-nix.url = "github:adisbladis/pyproject.nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      uv2nix,
      pyproject-nix,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Load workspace from uv.lock + pyproject.toml
        workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };

        # Overlay that makes dependencies available
        overlay = workspace.mkPyprojectOverlay {
          sourcePreference = "wheel";
        };

        # Python set with uv2nix overlay
        pythonSet =
          (pkgs.callPackage pyproject-nix.build.packages {
            python = pkgs.python3;
          }).overrideScope
            overlay;

      in
      {
        # Build with standard nixpkgs (uv2nix for dev/dependency lock)
        packages.default = pkgs.python3.pkgs.buildPythonApplication {
          pname = "my-app";
          version = "0.1.0";
          src = ./.;
          format = "pyproject";
          nativeBuildInputs = with pkgs.python3.pkgs; [ hatchling ];
        };

        # uv2nix-managed virtualenv (for dependency-locked builds)
        packages.uv2nix = pythonSet.mkVirtualEnv "my-app-env" { };

        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.uv
            pkgs.python3
            pkgs.python3.pkgs.pytest
            pkgs.python3.pkgs.ruff
          ];
          shellHook = ''
            echo "Python dev environment (uv2nix)"
            echo "Commands: uv run pytest, uv add <pkg>, uv lock"
          '';
        };

        checks = {
          formatting =
            pkgs.runCommand "check-formatting"
              {
                nativeBuildInputs = with pkgs; [
                  ruff
                  nixfmt
                ];
                src = ./.;
              }
              ''
                cd $src
                nixfmt --check *.nix
                RUFF_CACHE_DIR="$TMPDIR" ruff check --diff src/
                touch $out
              '';

          tests =
            pkgs.runCommand "run-tests"
              {
                buildInputs = [
                  pkgs.python3
                  pkgs.python3.pkgs.pytest
                ];
                src = ./.;
              }
              ''
                cd $src
                export PYTHONPATH="$src/src:$PYTHONPATH"
                python -m pytest tests/
                touch $out
              '';
        };

        formatter = pkgs.nixfmt;
      }
    );
}
