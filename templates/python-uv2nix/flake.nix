{
  description = "Python project managed with uv2nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
    nix2container.url = "github:nlewo/nix2container";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";
    mk-shell-bin.url = "github:rrbutani/nix-mk-shell-bin";
    uv2nix.url = "github:adisbladis/uv2nix";
    pyproject-nix.url = "github:adisbladis/pyproject.nix";
  };

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.devenv.flakeModule
      ];

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      perSystem =
        { config, pkgs, ... }:
        let
          workspace = inputs.uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };

          overlay = workspace.mkPyprojectOverlay {
            sourcePreference = "wheel";
          };

          pythonSet =
            (pkgs.callPackage inputs.pyproject-nix.build.packages {
              python = pkgs.python3;
            }).overrideScope
              overlay;
        in
        {
          packages.default = pkgs.python3.pkgs.buildPythonApplication {
            pname = "my-app";
            version = "0.1.0";
            src = ./.;
            format = "pyproject";
            nativeBuildInputs = with pkgs.python3.pkgs; [ hatchling ];
          };

          packages.uv2nix = pythonSet.mkVirtualEnv "my-app-env" { };

          devenv.shells.default = {
            imports = [ ./devenv.nix ];
            packages = [ config.packages.default ];
            devenv.root = toString ./.;
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
                  buildInputs = with pkgs; [
                    python3
                    python3.pkgs.pytest
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
        };
    };
}
