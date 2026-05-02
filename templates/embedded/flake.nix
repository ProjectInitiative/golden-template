{
  description = "Embedded firmware project (ESP-IDF)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    esp-dev.url = "github:mirrexagon/nixpkgs-esp-dev";
  };

  outputs = { self, nixpkgs, flake-utils, esp-dev }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Import scripts
        scripts = import ./nix/scripts.nix { inherit pkgs; };

        inherit (scripts)
          buildFirmware
          uploadFirmware
          monitorFirmware
          ciReady
          agentCheck
          mkFormattingTools
          ;
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "my-firmware";
          version = "0.1.0";
          src = ./.;
          nativeBuildInputs = [
            esp-dev.packages.${system}.esp-idf-full
          ];
          IDF_TARGET = "esp32s3";

          configurePhase = ''
            export HOME=$TMPDIR
          '';
          buildPhase = ''
            export IDF_COMPONENT_MANAGER=1
            export IDF_COMPONENT_MANAGER_OFFLINE=1
            idf.py build
          '';
          installPhase = ''
            mkdir -p $out
            cp build/*.bin $out/
            cp build/*.elf $out/
          '';
        };

        packages.tests = pkgs.stdenv.mkDerivation {
          name = "host-tests";
          src = ./.;
          nativeBuildInputs = [ pkgs.gcc pkgs.python3 ];
          buildPhase = ''
            python3 tools/test_runner.py
          '';
          installPhase = "mkdir -p $out";
        };

        checks = {
          formatting = pkgs.runCommand "check-formatting" {
            nativeBuildInputs = mkFormattingTools pkgs;
            src = ./.;
          } ''
            cp -r $src/. .
            chmod -R +w .
            treefmt --fail-on-change
            touch $out
          '';

          tests = self.packages.${system}.tests;
        };

        devShells.default = esp-dev.devShells.${system}.esp-idf-full.overrideAttrs (old: {
          buildInputs = old.buildInputs ++ mkFormattingTools pkgs ++ [
            pkgs.python3
            pkgs.esptool
            buildFirmware
            uploadFirmware
            monitorFirmware
            ciReady
            agentCheck
          ];

          shellHook = ''
            ${old.shellHook or ""}
            echo "Embedded dev environment (ESP-IDF)"
            echo "Commands: build-firmware, upload-firmware, monitor-firmware, ci-ready"
          '';
        });

        formatter = pkgs.nixfmt-rfc-style;
      }
    );
}
