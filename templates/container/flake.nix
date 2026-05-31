{
  description = "Nix-built OCI container images — patterns reference";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
    nix2container.url = "github:nlewo/nix2container";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";
    mk-shell-bin.url = "github:rrbutani/nix-mk-shell-bin";
    ops-utils.url = "github:projectinitiative/ops-utils";
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
        {
          config,
          self',
          pkgs,
          ...
        }:
        let
          ops = inputs.ops-utils.lib.mkUtils { inherit pkgs; };

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
          packages = {
            default = simple-image;
            inherit (ops) build-image push-multi-arch push-insecure;
            inherit
              multiuser-image
              layered-image
              configured-image
              ;
          };

          apps = {
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
          # Merge ops-utils apps
          // builtins.mapAttrs (name: value: value) (inputs.ops-utils.lib.mkApps { inherit pkgs; } ops);

          devenv.shells.default = {
            imports = [ ./devenv.nix ];
            devenv.root = toString ./.;
          };

          checks = {
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

            build = self'.packages.default;
          };

          formatter = pkgs.nixfmt;
        };
    };
}
