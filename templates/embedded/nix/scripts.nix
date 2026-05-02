{ pkgs }:

let
  mkFormattingTools =
    pkgs: with pkgs; [
      treefmt
      clang-tools
      nixfmt
      prettier
      black
    ];

  buildFirmware = pkgs.writeShellScriptBin "build-firmware" ''
    export IDF_COMPONENT_MANAGER=1
    export IDF_COMPONENT_MANAGER_OFFLINE=1
    idf.py build
  '';

  uploadFirmware = pkgs.writeShellScriptBin "upload-firmware" ''
    PORT_OR_IP=$1
    if [ -z "$PORT_OR_IP" ]; then
      echo "Usage: upload-firmware <serial-port|ip-address>"
      exit 1
    fi
    if [[ "$PORT_OR_IP" =~ ^/dev/ ]]; then
      esptool.py --chip esp32s3 --port "$PORT_OR_IP" write_flash @flash_args
    else
      curl -X POST "http://$PORT_OR_IP/ota" --data-binary @build/my-firmware.bin
    fi
  '';

  monitorFirmware = pkgs.writeShellScriptBin "monitor-firmware" ''
    PORT=$1
    if [ -z "$PORT" ]; then
      echo "Usage: monitor-firmware <serial-port>"
      exit 1
    fi
    miniterm --raw "$PORT" 115200
  '';

  ciReady = pkgs.writeShellScriptBin "ci-ready" ''
    set -e
    echo "=== CI Readiness Check ==="
    echo "1. Checking formatting..."
    treefmt --fail-on-change
    echo "2. Running tests..."
    python3 tools/test_runner.py
    echo "3. Building firmware..."
    nix build
    echo "=== All checks passed ==="
  '';

  agentCheck = pkgs.writeShellScriptBin "agent-check" ''
    set -e
    echo "=== Agent Pre-Submission Check ==="
    if [ -n "$(git status --porcelain)" ]; then
      echo "ERROR: Working tree is dirty. Commit all changes first."
      exit 1
    fi
    ci-ready
    echo "=== Agent check passed ==="
  '';

in
{
  inherit
    buildFirmware
    uploadFirmware
    monitorFirmware
    ciReady
    agentCheck
    mkFormattingTools
    ;
}
