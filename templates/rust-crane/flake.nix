{
  description = "Rust project built with crane";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    crane.url = "github:ipetkov/crane";
    fenix.url = "github:nix-community/fenix";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      crane,
      fenix,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Toolchain pinned via fenix (nightly or stable)
        toolchain = fenix.packages.${system}.stable.toolchain;
        craneLib = (crane.mkLib pkgs).overrideToolchain toolchain;

        # Common arguments for both deps and main build
        commonArgs = {
          src = craneLib.cleanCargoSource ./.;
          nativeBuildInputs = with pkgs; [ pkg-config ];
          buildInputs = with pkgs; [
            # Add system libraries here (openssl, zlib, etc.)
          ];
        };

        # Separate dep build for caching
        cargoArtifacts = craneLib.buildDepsOnly commonArgs;

      in
      {
        packages.default = craneLib.buildPackage (
          commonArgs
          // {
            inherit cargoArtifacts;
          }
        );

        devShells.default = pkgs.mkShell {
          inputsFrom = [ self.packages.${system}.default ];
          packages = with pkgs; [
            toolchain
            cargo-edit
            cargo-watch
            rust-analyzer
          ];
          shellHook = ''
            echo "Rust dev environment (crane)"
            echo "Commands: cargo build, cargo test, cargo fmt"
          '';
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

          tests = self.packages.${system}.default;
        };

        formatter = pkgs.nixfmt;
      }
    );
}
