{ pkgs, ... }:
{
  languages.go.enable = true;

  enterShell = ''
    echo "Go dev environment"
    echo "Commands: go build, go test, go fmt, go vet"
  '';

  git-hooks.hooks = {
    gofmt.enable = true;
    nixfmt-rfc-style.enable = true;
  };

  enterTest = ''
    go test ./...
  '';
}
