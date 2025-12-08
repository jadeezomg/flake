#!/usr/bin/env nu
# Update flake inputs
# Usage: update.nu [input]

use common.nu *

def main [input?: string] {
  print-header "UPDATE"
  let flake_path = (get-flake-path)
  
  if ($input | is-empty) {
    notify "Flake Update" "Updating all flake inputs..." "pending"
    nix flake update --flake $flake_path
    notify "Flake Update" "Flake inputs updated. See terminal for details." "success"
  } else {
    notify "Flake Update" $"Updating input: ($input)..." "pending"
    nix flake update --update-input $input --flake $flake_path
    notify "Flake Update" $"Updated input: ($input)" "success"
  }
  print-header "END"
}

