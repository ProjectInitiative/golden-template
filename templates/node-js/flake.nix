{
  description = "Node.js/TypeScript project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        nodejs = pkgs.nodejs_22;
      in
      {
        packages.default = pkgs.buildNpmPackage {
          pname = "my-app";
          version = "0.1.0";
          src = ./.;
          npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
          nativeBuildInputs = [ nodejs ];
          buildPhase = "npm run build";
          installPhase = "cp -r dist $out";
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = [ self.packages.${system}.default ];
          packages = with pkgs; [
            nodejs
            nodePackages.typescript
            nodePackages.typescript-language-server
          ];
          shellHook = ''
            echo "Node.js dev environment"
            echo "Commands: npm run dev, npm test, npm run build"
          '';
        };

        checks = {
          formatting = pkgs.runCommand "check-formatting" {
            nativeBuildInputs = with pkgs; [ nixfmt-rfc-style nodejs ];
            src = ./.;
          } ''
            cd $src
            nixfmt --check *.nix
            npx prettier --check .
            touch $out
          '';

          tests = pkgs.runCommand "run-tests" {
            nativeBuildInputs = [ self.devShells.${system}.default ];
            src = ./.;
          } ''
            cd $src
            npm test
            touch $out
          '';
        };

        formatter = pkgs.nixfmt-rfc-style;
      }
    );
}
