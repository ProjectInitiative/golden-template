{
  description = "Nix wrapper for upstream project (no source in repo)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Upstream source — fetched by Nix, not committed to this repo
    upstream-src = {
      url = "github:owner/project/v1.0.0";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      upstream-src,
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.stdenv.mkDerivation {
            pname = "my-project";
            version = "0.1.0";
            src = upstream-src;
            nativeBuildInputs = with pkgs; [ ];
            buildInputs = with pkgs; [ ];
            buildPhase = ''
              # Build using upstream source
              make
            '';
            installPhase = ''
              mkdir -p $out/bin
              cp my-binary $out/bin/
            '';
          };
        }
      );

      # NixOS module (optional — expose if this project provides a system service)
      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        {
          options.services.my-project = {
            enable = lib.mkEnableOption "my-project service";
            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.system}.default;
            };
          };
          config = lib.mkIf config.services.my-project.enable {
            systemd.services.my-project = {
              description = "My Project Service";
              wantedBy = [ "multi-user.target" ];
              serviceConfig.ExecStart = "${config.services.my-project.package}/bin/my-binary";
            };
          };
        };

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          setupLocalSource = pkgs.writeShellScriptBin "setup-local-source" ''
            echo "Setting up local source in .direnv/vendor..."
            mkdir -p .direnv/vendor
            if [ -d ".direnv/vendor/upstream" ]; then
              echo "Removing existing source..."
              rm -rf .direnv/vendor/upstream
            fi
            echo "Copying from Nix store..."
            cp -r ${upstream-src} .direnv/vendor/upstream
            chmod -R +w .direnv/vendor/upstream
            echo "Done. Source is in .direnv/vendor/upstream"
            echo "You can now edit and rebuild with: nix build"
          '';

          buildLocal = pkgs.writeShellScriptBin "build-local" ''
            if [ ! -d ".direnv/vendor/upstream" ]; then
              echo "Error: Local source not found. Run 'setup-local-source' first."
              exit 1
            fi
            cd .direnv/vendor/upstream
            echo "Building from local source..."
            make
          '';

        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              setupLocalSource
              buildLocal
              git
            ];
            shellHook = ''
              echo "Wrapper project dev shell"
              echo "Commands:"
              echo "  setup-local-source  : Copy source to .direnv/vendor/ for editing"
              echo "  build-local         : Build from local source copy"
              echo "  nix build           : Build from pinned flake input"
            '';
          };
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          formatting =
            pkgs.runCommand "check-formatting"
              {
                nativeBuildInputs = with pkgs; [ nixfmt ];
                src = ./.;
              }
              ''
                cd $src
                nixfmt --check *.nix
                touch $out
              '';
          build = self.packages.${system}.default;
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
