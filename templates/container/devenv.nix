{ pkgs, ... }:
{
  packages = with pkgs; [
    docker
    skopeo
  ];

  enterShell = ''
    echo "Container build environment"
    echo "Commands:"
    echo "  nix build .#default           : Simple image"
    echo "  nix build .#multiuser-image   : With users, entrypoint, env"
    echo "  nix build .#layered-image     : streamLayeredImage (modern)"
    echo "  nix build .#configured-image  : With fakeRootCommands"
    echo "  nix run .#push-multi-arch ... : Multi-arch push"
  '';

  git-hooks.hooks.nixfmt-rfc-style.enable = true;
}
