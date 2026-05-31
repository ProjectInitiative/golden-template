{ pkgs, ... }:
{
  packages = with pkgs; [
    hello
    jq
    yq
    ripgrep
    fd
  ];

  enterShell = ''
    echo "Dev shell only (no package build)"
    echo "Available tools: hello, jq, yq, rg, fd"
  '';

  git-hooks.hooks.nixfmt-rfc-style.enable = true;
}
