{
  config,
  pkgs,
  lib,
  ...
}:
{
  services.nginx = {
    enable = true;
    virtualHosts."localhost" = {
      locations."/" = {
        root = pkgs.runCommand "doc-root" { } ''
          mkdir -p $out
          echo "Hello from my-host!" > $out/index.html
        '';
      };
    };
  };
}
