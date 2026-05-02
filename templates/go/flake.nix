{
  description = "Go project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages.default = pkgs.buildGoModule {
          pname = "my-app";
          version = "0.1.0";
          src = ./.;
          vendorHash = null;
          subPackages = [ "." ];
          nativeBuildInputs = with pkgs; [ ];
          buildInputs = with pkgs; [ ];
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = [ self.packages.${system}.default ];
          packages = with pkgs; [
            go
            gopls
            gotools
            delve
          ];
          shellHook = ''
            echo "Go dev environment"
            echo "Commands: go build, go test, go fmt, go vet"
          '';
        };

        checks = {
          formatting =
            pkgs.runCommand "check-formatting"
              {
                nativeBuildInputs = with pkgs; [
                  nixfmt
                  go
                ];
                src = ./.;
              }
              ''
                cd $src
                nixfmt --check *.nix
                [ -z "$(gofmt -l .)" ] || exit 1
                touch $out
              '';

          tests =
            pkgs.runCommand "run-tests"
              {
                nativeBuildInputs = with pkgs; [ go ];
                src = ./.;
              }
              ''
                export HOME="$TMPDIR"
                cd $src
                go test ./...
                touch $out
              '';
        };

        formatter = pkgs.nixfmt;
      }
    );
}
