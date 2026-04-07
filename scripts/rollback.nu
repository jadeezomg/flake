#!/usr/bin/env nu
# Rollback to previous NixOS generation
# Usage: rollback.nu

use common.nu *

def main [] {
  print-header "ROLLBACK"
  let is_darwin = (is-darwin)
  notify "Flake Rollback" "Rolling back to previous generation..." "pending"
  
  if $is_darwin {
    # Darwin doesn't have nh darwin rollback, use darwin-rebuild instead
    let result = (^darwin-rebuild switch --rollback | complete)
    if $result.exit_code == 0 {
      notify "Flake Rollback" "Rollback complete" "success"
    } else {
      notify "Flake Rollback" $"Failed to rollback: ($result.stderr)" "error"
    }
  } else {
    nh os rollback
    notify "Flake Rollback" "Rollback complete" "success"
  }
  print-header "END"
}

