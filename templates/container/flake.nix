{
  description = "Nix-built OCI container images — patterns reference";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    ops-utils.url = "github:projectinitiative/ops-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ops-utils,
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
          ops = ops-utils.lib.mkUtils { inherit pkgs; };

          # -------------------------------------------------------------------
          # PATTERN 1: Simple image with buildEnv + copyToRoot
          # Use for: minimal images with a few dependencies
          # -------------------------------------------------------------------
          my-app = pkgs.writeShellScriptBin "my-app" ''
            echo "Hello from container!"
          '';

          simple-image = pkgs.dockerTools.buildImage {
            name = "my-app";
            tag = "latest";
            copyToRoot = pkgs.buildEnv {
              name = "image-root";
              paths = [ my-app ];
              pathsToLink = [ "/bin" ];
            };
            config.Cmd = [ "${my-app}/bin/my-app" ];
          };

          # -------------------------------------------------------------------
          # PATTERN 2: Image with custom /etc/passwd + /etc/group
          # Use for: images that need specific users (non-root, su-exec, etc.)
          # -------------------------------------------------------------------
          etcFiles = pkgs.runCommand "etc-files" { } ''
            mkdir -p $out/etc
            echo "root:x:0:0:root:/root:/bin/sh" > $out/etc/passwd
            echo "nobody:x:65534:65534:nobody:/:" >> $out/etc/passwd
            echo "appuser:x:1000:1000:App User:/home/appuser:/bin/sh" >> $out/etc/passwd
            echo "root:x:0:" > $out/etc/group
            echo "nobody:x:65534:" >> $out/etc/group
            echo "appuser:x:1000:" >> $out/etc/group
          '';

          entrypoint = pkgs.writeShellScript "entrypoint.sh" ''
            set -e
            echo "App started as $(whoami)"
            exec "$@"
          '';

          multiuser-image = pkgs.dockerTools.buildImage {
            name = "my-app-multiuser";
            tag = "latest";
            copyToRoot = pkgs.buildEnv {
              name = "image-root";
              paths = [
                my-app
                pkgs.su-exec
                pkgs.coreutils
                pkgs.bash
                etcFiles
              ];
              postBuild = ''
                mkdir -p $out/data $out/tmp $out/home/appuser
                cp ${entrypoint} $out/entrypoint.sh
                chmod +x $out/entrypoint.sh
              '';
            };
            config = {
              Cmd = [ "${my-app}/bin/my-app" ];
              Entrypoint = [ "${entrypoint}" ];
              User = "1000";
              Env = [
                "PATH=${
                  pkgs.lib.makeBinPath [
                    my-app
                    pkgs.coreutils
                  ]
                }"
              ];
              WorkingDir = "/data";
              ExposedPorts = {
                "8080/tcp" = { };
              };
            };
          };

          # -------------------------------------------------------------------
          # PATTERN 3: streamLayeredImage (modern, no layer limit)
          # Use for: large images or when you need fine-grained layer control
          # The image is produced as a tarball (OCI format)
          # -------------------------------------------------------------------
          layered-image = pkgs.dockerTools.streamLayeredImage {
            name = "my-app-layered";
            tag = "latest";
            # contents adds packages to the image (like copyToRoot but layered)
            contents = [
              my-app
              pkgs.coreutils
              pkgs.bash
              etcFiles
            ];
            config = {
              Cmd = [ "${my-app}/bin/my-app" ];
              User = "1000";
              Env = [
                "PATH=${
                  pkgs.lib.makeBinPath [
                    my-app
                    pkgs.coreutils
                  ]
                }"
              ];
            };
          };

          # -------------------------------------------------------------------
          # PATTERN 4: Image with runAsRoot (setup commands during build)
          # Use for: creating files, permissions, users at build time
          # -------------------------------------------------------------------
          configured-image = pkgs.dockerTools.buildImage {
            name = "my-app-configured";
            tag = "latest";
            copyToRoot = pkgs.buildEnv {
              name = "image-root";
              paths = [
                my-app
                pkgs.bash
                pkgs.coreutils
                etcFiles
              ];
            };
            runAsRoot = ''
              mkdir -p /data /config
              chown -R 1000:1000 /data /config
              echo "app_mode=production" > /config/settings.env
            '';
            config.Cmd = [ "${my-app}/bin/my-app" ];
          };

        in
        {
          default = simple-image;
          inherit (ops) build-image push-multi-arch push-insecure;
          inherit
            multiuser-image
            layered-image
            configured-image
            ;
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
                nix build .#default -o result-image
                docker load < result-image
                echo "Also available: nix build .#multiuser-image, .#layered-image, .#configured-image"
              ''
            );
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              docker
              skopeo
              nix-build-uncached
            ];
            shellHook = ''
              echo "Container dev environment"
              echo "Commands:"
              echo "  nix build .#default           : Simple image"
              echo "  nix build .#multiuser-image   : With users, entrypoint, env"
              echo "  nix build .#layered-image     : streamLayeredImage (modern)"
              echo "  nix build .#configured-image  : With fakeRootCommands"
              echo "  nix run .#push-multi-arch ... : Multi-arch push"
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
                nativeBuildInputs = [ pkgs.nixfmt ];
                src = ./.;
              }
              ''
                nixfmt --check $src/*.nix
                touch $out
              '';
          build = self.packages.${system}.default;
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
