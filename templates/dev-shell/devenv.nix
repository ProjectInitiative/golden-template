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

  # Uncomment to run OpenBao (open-source Vault) for local secrets management:
  # services.vault = {
  #   enable = true;
  #   package = pkgs.openbao;
  # };
  #
  # Start with: devenv up
  # Then: export VAULT_ADDR=http://127.0.0.1:8200
  #       vault secrets enable -path=kv kv-v2
  #       vault kv put kv/dev/db password=localdev
}
