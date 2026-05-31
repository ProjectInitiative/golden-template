{
  description = "Rust project built with crane";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
    nix2container.url = "github:nlewo/nix2container";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";
    mk-shell-bin.url = "github:rrbutani/nix-mk-shell-bin";
    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    crane.url = "github:ipetkov/crane";
    fenix.url = "github:nix-community/fenix";
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
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      perSystem =
        {
          config,
          self',
          pkgs,
          system,
          ...
        }:
        let
          toolchain = inputs.fenix.packages.${system}.stable.toolchain;
          craneLib = (inputs.crane.mkLib pkgs).overrideToolchain toolchain;

          commonArgs = {
            src = craneLib.cleanCargoSource ./.;
            nativeBuildInputs = with pkgs; [ pkg-config ];
            buildInputs = with pkgs; [ ];
          };

          cargoArtifacts = craneLib.buildDepsOnly commonArgs;
        in
        {
          packages.default = craneLib.buildPackage (
            commonArgs
            // {
              inherit cargoArtifacts;
            }
          );

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
                    nixfmt
                    cargo
                    rustfmt
                  ];
                  src = ./.;
                }
                ''
                  cd $src
                  nixfmt --check *.nix
                  cargo fmt --check
                  touch $out
                '';

            tests = self'.packages.default;
          };

          formatter = pkgs.nixfmt;
        };
    };
}
