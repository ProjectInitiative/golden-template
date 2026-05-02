{
  description = "Development shell with tools (no package build)";

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
        # No packages.default — this is a shell-only project

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            # Add your tools here
            hello
            jq
            yq
            ripgrep
            fd
          ];
          shellHook = ''
            echo "Dev shell only (no package build)"
            echo "Available tools: hello, jq, yq, rg, fd"
          '';
        };

        checks.formatting =
          pkgs.runCommand "check-formatting"
            {
              nativeBuildInputs = with pkgs; [ nixfmt ];
              src = ./.;
            }
            ''
              nixfmt --check $src/*.nix
              touch $out
            '';

        formatter = pkgs.nixfmt;
      }
    );
}
