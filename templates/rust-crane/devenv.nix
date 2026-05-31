{ pkgs, ... }:
{
  languages.rust = {
    enable = true;
    channel = "stable";
    components = [
      "rustc"
      "cargo"
      "clippy"
      "rustfmt"
      "rust-analyzer"
    ];
  };

  packages = with pkgs; [
    cargo-edit
    cargo-watch
  ];

  enterShell = ''
    echo "Rust dev environment (crane + devenv)"
    echo "Commands: cargo build, cargo test, cargo fmt"
  '';

  git-hooks.hooks = {
    rustfmt.enable = true;
    clippy.enable = true;
    nixfmt-rfc-style.enable = true;
  };

  enterTest = ''
    cargo test
  '';
}
