{
  description = "ProjectInitiative Golden Template: Standards, documentation, and scaffolding for Nix-based projects";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        formatter = pkgs.nixfmt-rfc-style;

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            nixfmt-rfc-style
            just
            mdbook
          ];
          shellHook = ''
            echo "Golden Template Dev Shell"
            echo "Available: nix flake show, nix flake init -t .#<template>"
          '';
        };
      }
    ) // {
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
      };
    };
}
