#!/usr/bin/env nu
# Update flake inputs
# Usage: update.nu [input]

use common.nu *

def main [] {
  print-header "UPDATE"
  let flake_path = (get-flake-path)
  let is_darwin = (is-darwin)
  let cmd_prefix = (if $is_darwin { "nh darwin" } else { "nh os" })
  notify "Flake Update" "Updating all flake inputs..." "pending"
  ^bash -c $"($cmd_prefix) switch --update --dry"
  notify "Flake Update" "Flake inputs updated. See terminal for details." "success"
  print-header "END"
}

