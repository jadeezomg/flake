#!/usr/bin/env nu
# Show flake metadata (parity with rh-flake-info.sh)

use common.nu *

def main [] {
  print-header "FLAKE INFO"
  let flake_path = (get-flake-path)
  ^nix flake metadata $flake_path
  print-header "END"
}


