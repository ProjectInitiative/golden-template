{
  description = "ProjectInitiative Golden Template: Standards, documentation, and scaffolding for Nix-based projects";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        validateTemplates = pkgs.writeShellScriptBin "validate-templates" ''
          exec ${./nix/validate-templates.sh}
        '';

        agentCheck = pkgs.writeShellScriptBin "agent-check" ''
          set -euo pipefail
          echo "=== Agent Pre-Submission Check ==="

          echo "1. Checking working tree..."
          if [ -n "$(git status --porcelain)" ]; then
            echo "ERROR: Working tree is dirty. Commit all changes first."
            exit 1
          fi

          echo "2. Checking formatting..."
          treefmt --fail-on-change

          echo "3. Validating all templates..."
          ${./nix/validate-templates.sh}

          echo "=== All checks passed ==="
        '';

      in
      {
        packages.validate-templates = validateTemplates;
        packages.agent-check = agentCheck;

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            nixfmt
            treefmt
            prettier
            ruff
            rustfmt
            go
            clang-tools
            shfmt
            just
            mdbook
            nodejs_22
            uv
            validateTemplates
            agentCheck
          ];
          shellHook = ''
            echo "Golden Template Dev Shell"
            echo "Available: nix flake show, nix flake init -t .#<template>"
            echo "Commands: validate-templates, agent-check"
          '';
        };

        checks.formatting =
          pkgs.runCommand "check-formatting"
            {
              nativeBuildInputs = with pkgs; [
                treefmt
                nixfmt
                prettier
                ruff
                rustfmt
                go
                clang-tools
                shfmt
              ];
              src = ./.;
            }
            ''
              cp -r $src/. .
              chmod -R +w .
              export XDG_CACHE_HOME=$TMPDIR
              treefmt --fail-on-change
              touch $out
            '';

        formatter = pkgs.nixfmt;
      }
    )
    // {
      templates = {
        python = {
          path = ./templates/python-uv2nix;
          description = "Python project using uv2nix for dependency management";
        };
        rust = {
          path = ./templates/rust-crane;
          description = "Rust project using crane for incremental cargo builds";
        };
        go = {
          path = ./templates/go;
          description = "Go project using buildGoModule";
        };
        node = {
          path = ./templates/node-js;
          description = "Node.js/TypeScript project using buildNpmPackage";
        };
        embedded = {
          path = ./templates/embedded;
          description = "Embedded/firmware project (ESP-IDF, Arduino, etc.)";
        };
        container = {
          path = ./templates/container;
          description = "Nix-built OCI container image with multi-arch push";
        };
        dev-shell = {
          path = ./templates/dev-shell;
          description = "Pure development shell with tools (no package build)";
        };
        nix-library = {
          path = ./templates/nix-library;
          description = "Shared Nix library flake exposing reusable functions";
        };
        nixos-config = {
          path = ./templates/nixos-config;
          description = "NixOS system configuration flake";
        };
        wrapper = {
          path = ./templates/wrapper-project;
          description = "Nix wrapper around upstream source (no code in repo, .direnv/vendor/ workflow)";
        };
      };
    };
}
