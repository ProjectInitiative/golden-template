{ pkgs, ... }:
{
  languages.python = {
    enable = true;
    venv.enable = true;
    venv.requirements = ''
      pytest
      ruff
    '';
    uv.enable = true;
    uv.sync.enable = true;
  };

  packages = [ pkgs.uv ];

  enterShell = ''
    echo "Python dev environment (uv2nix + devenv)"
    echo "Commands: uv run pytest, uv add <pkg>, uv lock"
  '';

  git-hooks.hooks = {
    ruff.enable = true;
    nixfmt-rfc-style.enable = true;
  };

  enterTest = ''
    uv run pytest tests/
  '';
}
