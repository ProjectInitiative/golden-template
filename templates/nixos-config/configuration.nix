{
  config,
  pkgs,
  lib,
  ...
}:
{
  system.stateVersion = "25.11";

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  fileSystems."/" = {
    device = "/dev/sda1";
    fsType = "ext4";
  };

  networking.hostName = "my-host";
  networking.networkmanager.enable = true;

  services.openssh.enable = true;

  users.users.root.initialPassword = "root";

  environment.systemPackages = with pkgs; [
    vim
    htop
  ];
}
