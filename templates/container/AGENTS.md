# Agent Working Guide — Container Images

## Available Images

| Pattern          | Build command                  | Use case                                            |
| ---------------- | ------------------------------ | --------------------------------------------------- |
| simple-image     | `nix build .#default`          | Minimal image, few deps                             |
| multiuser-image  | `nix build .#multiuser-image`  | Custom users, entrypoint, env, ports                |
| layered-image    | `nix build .#layered-image`    | Large images, no layer limit (`streamLayeredImage`) |
| configured-image | `nix build .#configured-image` | Build-time setup via `fakeRootCommands`             |

## Key Patterns

### copyToRoot + buildEnv

```nix
copyToRoot = pkgs.buildEnv {
  paths = [ my-app pkgs.bash ];
  postBuild = ''
    mkdir -p $out/data
    cp ${someConfig} $out/config.yaml
  '';
};
```

### Custom /etc/passwd and /etc/group

```nix
etcFiles = pkgs.runCommand "etc-files" {} ''
  mkdir -p $out/etc
  echo "appuser:x:1000:1000:App User:/home/appuser:/bin/sh" >> $out/etc/passwd
  echo "appuser:x:1000:" >> $out/etc/group
'';
```

Then add `etcFiles` to `copyToRoot.paths`.

### Entrypoint wrapping

```nix
entrypoint = pkgs.writeShellScript "entrypoint.sh" ''
  set -e
  exec "$@"
'';
```

### Environment with PATH

```nix
config.Env = [
  "PATH=${pkgs.lib.makeBinPath [ my-app pkgs.coreutils ]}"
];
```

### Multi-arch Push

```bash
nix run .#push-multi-arch -- multiuser-image my-image-name ghcr.io/owner
```
