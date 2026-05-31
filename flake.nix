{
  description = "ProjectInitiative Golden Template: Standards, documentation, and scaffolding for Nix-based projects";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
  };

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.devenv.flakeModule
      ];

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      perSystem =
        { config, pkgs, ... }:
        let
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
          packages = {
            inherit validateTemplates agentCheck;
          };

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
              echo "See templates/ for devenv-powered project templates"
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
                export HOME=$TMPDIR
                treefmt --fail-on-change
                touch $out
              '';

          formatter = pkgs.nixfmt;
        };

      flake = {
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
          compiled-serverless = {
            path = ./templates/compiled-serverless;
            description = "Compiled Go service with multi-arch builds, multi-headed binary pattern, and Fission serverless deployment";
          };
          wrapper = {
            path = ./templates/wrapper-project;
            description = "Nix wrapper around upstream source (no code in repo, .direnv/vendor/ workflow)";
          };
          ingestion-pipeline = {
            path = ./templates/ingestion-pipeline;
            description = "S3/NATS/K8s ingestion pipeline with Fission serverless functions for direct-upload media processing";
          };
        };
      };
    };
}
