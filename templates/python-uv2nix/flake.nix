{
  description = "Python project managed with uv2nix";

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

        # Load workspace from uv.lock + pyproject.toml
        workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };

        # Overlay that makes dependencies available
        overlay = workspace.mkPyprojectOverlay {
          sourcePreference = "wheel";
        };

        # Python environment set
        pythonSet = pkgs.callPackage pyproject-nix.build.packages {
          python = pkgs.python3;
        }.overrideScope [ overlay ];

      in
      {
        packages.default = pythonSet.mkVirtualEnv "my-app-env" {
          # Populated from pyproject.toml [project] deps
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = [ self.packages.${system}.default ];
          packages = with pkgs; [
            uv
            pytest
            pytest-asyncio
            ruff
            mypy
          ];
          shellHook = ''
            echo "Python dev environment (uv2nix)"
            echo "Commands: uv run pytest, uv add <pkg>, uv lock"
          '';
        };

        checks = {
          formatting = pkgs.runCommand "check-formatting" {
            nativeBuildInputs = with pkgs; [ ruff ];
            src = ./.;
          } ''
            ruff check --diff $src
            touch $out
          '';

          tests = pkgs.runCommand "run-tests" {
            nativeBuildInputs = [ self.devShells.${system}.default ];
            src = ./.;
          } ''
            cd $src
            python -m pytest
            touch $out
          '';
        };

        formatter = pkgs.nixfmt-rfc-style;
      }
    );
}
