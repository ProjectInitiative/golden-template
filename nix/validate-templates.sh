#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
TEMPLATES=("python-uv2nix" "rust-crane" "go" "node-js" "embedded" "container" "dev-shell" "nix-library" "nixos-config")
EXCLUDED_FROM_BUILD=("nixos-config" "embedded" "dev-shell" "nix-library")  # need special toolchains or no package
PASS=0
FAIL=0
FAILED_TEMPLATES=""

cleanup() {
  rm -rf "$TMPDIR_ROOT"
}
trap cleanup EXIT

TMPDIR_ROOT=$(mktemp -d)

echo "=========================================="
echo "  Template Validation Suite"
echo "=========================================="
echo ""

for template in "${TEMPLATES[@]}"; do
  echo "--- Testing template: $template ---"

  TMPDIR=$(mktemp -d "$TMPDIR_ROOT/$template.XXXXXX")

  # Copy template files to temp dir
  rm -rf "$TMPDIR"/* 2>/dev/null
  cp -r "$REPO_ROOT/templates/$template"/* "$TMPDIR/"
  cp -r "$REPO_ROOT/templates/$template"/.* "$TMPDIR/" 2>/dev/null || true

  # Generate lock file
  nix flake lock "$TMPDIR" 2>&1 | tail -3 || {
    echo "FAIL: nix flake lock failed for $template"
    FAIL=$((FAIL + 1))
    FAILED_TEMPLATES="$FAILED_TEMPLATES $template"
    continue
  }

  # Run flake check (eval check)
  nix flake check "$TMPDIR" 2>&1 | tail -5 || {
    echo "FAIL: nix flake check failed for $template"
    FAIL=$((FAIL + 1))
    FAILED_TEMPLATES="$FAILED_TEMPLATES $template"
    continue
  }

  # Run nix build for buildable templates
  if [[ ! " ${EXCLUDED_FROM_BUILD[*]} " =~ " $template " ]]; then
    nix build "$TMPDIR" 2>&1 | tail -5 || {
      echo "FAIL: nix build failed for $template"
      FAIL=$((FAIL + 1))
      FAILED_TEMPLATES="$FAILED_TEMPLATES $template"
      continue
    }
  else
    echo "(skipping nix build for $template - needs special toolchain)"
  fi

  echo "PASS: $template"
  PASS=$((PASS + 1))
done

echo ""
echo "=========================================="
echo "  Results: $PASS passed, $FAIL failed"
echo "=========================================="

if [ "$FAIL" -gt 0 ]; then
  echo "Failed templates:$FAILED_TEMPLATES"
  exit 1
fi
