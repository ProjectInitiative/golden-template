{
  description = "Shared Nix library";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      lib =
        let
          mkMyUtil = import ./lib/my-util.nix;
        in
        {
          inherit mkMyUtil;

          # Convenience: instantiate all tools at once
          mkUtils =
            {
              pkgs,
              system ? pkgs.system,
            }:
            {
              my-util = mkMyUtil { inherit pkgs; };
            };

          # Generate apps from utils
          mkApps =
            { pkgs }:
            utils:
            pkgs.lib.mapAttrs (name: pkg: {
              type = "app";
              program = "${pkg}/bin/${name}";
            }) utils;
        };

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              nixfmt
            ];
          };
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
