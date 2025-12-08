#!/usr/bin/env nu
# Format Nix files in the flake (parity with rh-fmt.sh)

use common.nu *

def main [] {
  print-header "FMT"
  let flake_path = (get-flake-path)

  if not (command-exists "nixfmt") {
    print-error "nixfmt not found. Install nixfmt to format Nix files."
    exit 1
  }

  notify "Flake Fmt" "Formatting Nix files..." "pending"

  let files = (glob $"($flake_path)/**/*.nix")
  let count = ($files | length)

  if $count == 0 {
    notify "Flake Fmt" "No .nix files found." "info"
    return
  }

  # Run nixfmt per file to avoid argument length issues
  $files | each { |f| ^nixfmt $f }

  notify "Flake Fmt" $"Formatted ($count) files" "success"
  print-header "END"
}


