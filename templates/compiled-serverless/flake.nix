{
  description = "Multi-arch compiled service — deploy as monolith or Fission serverless function";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    ops-utils.url = "github:projectinitiative/ops-utils";
    crane.url = "github:ipetkov/crane";
    fenix.url = "github:nix-community/fenix";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ops-utils,
      crane,
      fenix,
    }:
    let
      # -------------------------------------------------------------------
      # Multi-arch pattern: declare which architectures you target.
      # Nix builds each system independently — `nix build` on an
      # aarch64-linux machine produces arm64 binaries automatically.
      # Cross-compilation happens for free via the Nix build farm or
      # remote builders.
      # -------------------------------------------------------------------
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      version = "0.1.0";
      rev = self.rev or "dirty";
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          ops = ops-utils.lib.mkUtils { inherit pkgs; };

          # -------------------------------------------------------------------
          # Go build helpers
          # -------------------------------------------------------------------
          mkGoModule =
            { pname, subPackages ? [ "." ] }:
            pkgs.buildGoModule {
              inherit pname subPackages;
              inherit version;
              # CGO_ENABLED=0 is automatic for cross-compilation in nixpkgs.
              # To force it: overrideAttrs (final: prev: { CGO_ENABLED = 0; })
              src = ./.;
              vendorHash = null;
              ldflags = [
                "-s"
                "-w"
                "-X main.Version=${version}+${rev}"
              ];
            };

          # -------------------------------------------------------------------
          # Rust build helpers (crane)
          # -------------------------------------------------------------------
          toolchain = fenix.packages.${system}.stable.toolchain;
          craneLib = (crane.mkLib pkgs).overrideToolchain toolchain;

          rustCommon = {
            src = craneLib.cleanCargoSource (./rust);
            nativeBuildInputs = with pkgs; [ pkg-config ];
            buildInputs = with pkgs; [ ];
          };

          rustCargoArtifacts = craneLib.buildDepsOnly rustCommon;

          mkRustBin = craneLib.buildPackage (
            rustCommon
            // {
              cargoArtifacts = rustCargoArtifacts;
              pname = "my-service-rust";
              inherit version;
            }
          );

          # -------------------------------------------------------------------
          # Container image builder
          # -------------------------------------------------------------------
          mkContainer =
            {
              name,
              binary,
              binName,
              cmd ? null,
              port ? "8080",
            }:
            let
              defaultCmd = "${binary}/bin/${binName}";
              effectiveCmd = if cmd != null then cmd else defaultCmd;
            in
            pkgs.dockerTools.buildImage {
              inherit name;
              tag = version;
              copyToRoot = pkgs.buildEnv {
                name = "${name}-root";
                paths = [ binary ];
                pathsToLink = [ "/bin" ];
              };
              config = {
                Cmd = [ effectiveCmd ];
                ExposedPorts = {
                  "${port}/tcp" = { };
                };
              };
            };

        in
        {
          # ===================================================================
          # BUILD TARGETS
          # ===================================================================

          # PATTERN: Multi-headed Go monolith binary (like fission-bundle)
          # Usage: my-service server | my-service function
          default = mkGoModule {
            pname = "my-service";
          };

          # PATTERN: Standalone Go Fission function binary
          fission-function = mkGoModule {
            pname = "fission-function";
            subPackages = [ "./cmd/function" ];
          };

          # PATTERN: Multi-headed Rust monolith binary
          # Usage: my-service-rust server | my-service-rust function
          rust-monolith = mkRustBin;

          # PATTERN: Standalone Rust Fission function binary
          rust-function = craneLib.buildPackage (
            rustCommon
            // {
              cargoArtifacts = rustCargoArtifacts;
              pname = "fission-function-rust";
              inherit version;
              cargoExtraArgs = "--bin fission-function";
            }
          );

          # ===================================================================
          # CONTAINER TARGETS
          # ===================================================================

          # PATTERN: OCI containers for Go deployment modes
          container-monolith = mkContainer {
            name = "my-service";
            binary = self.packages.${system}.default;
            binName = "my-service";
            cmd = "${self.packages.${system}.default}/bin/my-service server";
          };

          container-function = mkContainer {
            name = "my-fission-function";
            binary = self.packages.${system}.fission-function;
            binName = "fission-function";
            port = "8888";
          };

          # PATTERN: Fission function using the Go monolith binary.
          # The SAME binary deployed as a Fission function — just pass
          # the "function" argument as the container CMD.
          container-monolith-as-function = mkContainer {
            name = "my-service-fn";
            binary = self.packages.${system}.default;
            binName = "my-service";
            cmd = "${self.packages.${system}.default}/bin/my-service function";
            port = "8888";
          };

          # PATTERN: Rust containers
          container-rust-monolith = mkContainer {
            name = "my-service-rust";
            binary = self.packages.${system}.rust-monolith;
            binName = "my-service";
            cmd = "${self.packages.${system}.rust-monolith}/bin/my-service server";
          };

          container-rust-function = mkContainer {
            name = "my-fission-function-rust";
            binary = self.packages.${system}.rust-function;
            binName = "fission-function";
            port = "8888";
          };

          # Multi-arch container push helpers (from ops-utils)
          inherit (ops) build-image push-multi-arch push-insecure;
        }
      );

      apps = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          ops = ops-utils.lib.mkUtils { inherit pkgs; };
          opsApps = ops-utils.lib.mkApps { inherit pkgs; } ops;
        in
        opsApps
        // {
          build-all = {
            type = "app";
            program = toString (
              pkgs.writeShellScript "build-all" ''
                echo "Building all targets..."
                nix build '.#default' -o result-monolith
                nix build '.#fission-function' -o result-function
                nix build '.#rust-monolith' -o result-rust-monolith
                nix build '.#rust-function' -o result-rust-function
                nix build '.#container-monolith' -o result-container-monolith
                nix build '.#container-function' -o result-container-function
                echo "Done. Results in result-*"
              ''
            );
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          toolchain = fenix.packages.${system}.stable.toolchain;
        in
        {
          default = pkgs.mkShell {
            inputsFrom = [ self.packages.${system}.default ];
            packages = with pkgs; [
              go
              gopls
              gotools
              delve
              toolchain
              rust-analyzer
            ];
            shellHook = ''
              echo "Compiled Serverless Dev Shell"
              echo "Architecture: ${system}"
              echo ""
              echo "=== Architecture Pattern ==="
              echo "Multi-headed binary (like Fission's fission-bundle):"
              echo "  my-service server     — Go monolith"
              echo "  my-service function   — Go Fission function"
              echo ""
              echo "Also available in Rust:"
              echo "  my-service-rust server     — Rust monolith"
              echo "  my-service-rust function   — Rust Fission function"
              echo ""
              echo "=== Commands ==="
              echo "  go build ./...               : Build Go"
              echo "  go test ./...                : Test Go"
              echo "  cargo build                  : Build Rust"
              echo "  cargo test                   : Test Rust"
              echo "  nix build .#default           : Go monolith binary"
              echo "  nix build .#rust-monolith     : Rust monolith binary"
              echo "  nix build .#container-monolith: Go monolith container"
              echo "  nix run .#push-multi-arch ... : Push multi-arch"
            '';
          };
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          toolchain = fenix.packages.${system}.stable.toolchain;
        in
        {
          formatting =
            pkgs.runCommand "check-formatting"
              {
                nativeBuildInputs = with pkgs; [
                  nixfmt
                  go
                  toolchain
                ];
                src = ./.;
              }
              ''
                cd $src
                nixfmt --check *.nix
                [ -z "$(gofmt -l .)" ] || exit 1
                cargo fmt --check --manifest-path rust/Cargo.toml
                touch $out
              '';

          tests =
            pkgs.runCommand "run-tests"
              {
                nativeBuildInputs = with pkgs; [ go toolchain ];
                src = ./.;
              }
              ''
                export HOME="$TMPDIR"
                cd $src
                go test ./...
                cargo test --manifest-path rust/Cargo.toml
                touch $out
              '';

          build = self.packages.${system}.default;
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
