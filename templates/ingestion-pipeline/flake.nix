{
  description = "Ingestion pipeline — upload, queue, process, serve";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    uv2nix.url = "github:adisbladis/uv2nix";
    pyproject-nix.url = "github:adisbladis/pyproject.nix";
    pyproject-build-systems.url = "github:pyproject-nix/build-system-pkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      uv2nix,
      pyproject-nix,
      pyproject-build-systems,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };

        overlay = workspace.mkPyprojectOverlay {
          sourcePreference = "wheel";
        };

        buildSystemsOverlay = pyproject-build-systems.overlays.default;

        pythonSet =
          (pkgs.callPackage pyproject-nix.build.packages {
            python = pkgs.python3;
          }).overrideScope
            (nixpkgs.lib.composeExtensions buildSystemsOverlay overlay);

        agentCheck = pkgs.writeShellScriptBin "agent-check" ''
          set -euo pipefail
          echo "=== Agent Pre-Submission Check ==="

          echo "1. Checking working tree..."
          if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
            echo "ERROR: Working tree is dirty. Commit all changes first."
            exit 1
          fi

          echo "2. Checking formatting..."
          treefmt --fail-on-change

          echo "3. Running tests..."
          cd "$(git rev-parse --show-toplevel)"
          export PYTHONPATH="$PWD/src:$PYTHONPATH"
          python -m pytest tests/ -v

          echo "4. Verifying nix build..."
          nix build --no-link

          echo "=== All checks passed ==="
        '';

      in
      {
        packages.default = pythonSet.mkVirtualEnv "ingestion-pipeline-env" {
          ingestion-pipeline = [ ];
        };

        packages.agent-check = agentCheck;

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            uv
            python3
            python3.pkgs.pytest
            python3.pkgs.ruff
            nixfmt
            treefmt
            prettier
            rclone
            natscli
            agentCheck
          ];
          shellHook = ''
            echo "=== Ingestion Pipeline Dev Shell ==="
            echo "Commands:"
            echo "  uv run pytest             Run tests"
            echo "  uv add <pkg>              Add Python dep"
            echo "  uv lock                   Update lockfile"
            echo "  ruff check                Lint Python code"
            echo "  treefmt                   Format all code"
            echo "  nats                      NATS CLI"
            echo "  agent-check               Pre-submission validation"
          '';
        };

        checks = {
          formatting =
            pkgs.runCommand "check-formatting"
              {
                nativeBuildInputs = with pkgs; [
                  ruff
                  nixfmt
                  treefmt
                  prettier
                ];
                src = ./.;
              }
              ''
                cp -r $src/. .
                chmod -R +w .
                export XDG_CACHE_HOME=$TMPDIR
                treefmt --fail-on-change
                touch $out
              '';

          tests =
            pkgs.runCommand "run-tests"
              {
                buildInputs = with pkgs; [
                  python3
                  python3.pkgs.pytest
                ];
                src = ./.;
              }
              ''
                cp -r $src/. .
                chmod -R +w .
                export PYTHONPATH="$PWD/src:$PYTHONPATH"
                python -m pytest tests/ -v -p no:cacheprovider
                touch $out
              '';
        };

        formatter = pkgs.treefmt;
      }
    );
}
