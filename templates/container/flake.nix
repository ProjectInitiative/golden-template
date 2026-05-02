{
  description = "Nix-built OCI container images";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    ops-utils.url = "github:projectinitiative/ops-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ops-utils }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          ops = ops-utils.lib.mkUtils { inherit pkgs; };

          # The application to containerize
          my-app = pkgs.writeShellScriptBin "my-app" ''
            echo "Hello from container!"
          '';

          containerImage = pkgs.dockerTools.buildImage {
            name = "my-app";
            tag = "latest";
            copyToRoot = pkgs.buildEnv {
              name = "image-root";
              paths = [ my-app ];
              pathsToLink = [ "/bin" ];
            };
            config = {
              Cmd = [ "${my-app}/bin/my-app" ];
            };
          };

        in
        {
          default = containerImage;
          inherit (ops) build-image push-multi-arch push-insecure;
        }
      );

      apps = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          ops = ops-utils.lib.mkUtils { inherit pkgs; };
          opsApps = ops-utils.lib.mkApps { inherit pkgs; } ops;
        in
        opsApps // {
          build-all = {
            type = "app";
            program = toString (pkgs.writeShellScript "build-all" ''
              nix build .#default -o result-image
              docker load < result-image
            '');
          };
        }
      );

      devShells = forAllSystems (system:
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
              echo "Commands: build-image, push-multi-arch"
            '';
          };
        }
      );

      formatter = forAllSystems (system:
        nixpkgs.legacyPackages.${system}.nixfmt-rfc-style
      );
    };
}
