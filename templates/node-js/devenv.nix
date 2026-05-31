{ pkgs, ... }:
{
  languages.javascript = {
    enable = true;
    package = pkgs.nodejs_22;
    npm.enable = true;
    npm.install.enable = true;
  };

  enterShell = ''
    echo "Node.js dev environment"
    echo "Commands: npm run dev, npm test, npm run build"
  '';

  git-hooks.hooks = {
    prettier.enable = true;
    nixfmt-rfc-style.enable = true;
  };

  enterTest = ''
    npm test
  '';
}
