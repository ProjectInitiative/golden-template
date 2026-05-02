{ pkgs }:
pkgs.writeShellScriptBin "my-util" ''
  set -e
  echo "Hello from my-util!"
  echo "This is a reusable Nix library function."
''
