{
  description = "Go project";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
    nix2container.url = "github:nlewo/nix2container";
    nix2container.inputs.nixpkgs.follows = "nixpkgs";
    mk-shell-bin.url = "github:rrbutani/nix-mk-shell-bin";
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
        { config, pkgs, ... }:
        {
          packages.default = pkgs.buildGoModule {
            pname = "my-app";
            version = "0.1.0";
            src = ./.;
            vendorHash = null;
            subPackages = [ "." ];
          };

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
        };
    };
}
