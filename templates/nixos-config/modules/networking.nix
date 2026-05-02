{
  config,
  pkgs,
  lib,
  ...
}:
{
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [
    22
    80
    443
  ];
  networking.nameservers = [
    "1.1.1.1"
    "9.9.9.9"
  ];
}
