#!/usr/bin/env nu
# Show flake metadata (parity with rh-flake-info.sh)

use common.nu *

def main [] {
  let flake_path = (get-flake-path)
  ^nix flake metadata $flake_path
}


