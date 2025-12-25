#!/usr/bin/env nu
# Rollback to previous NixOS generation
# Usage: rollback.nu

use common.nu *

def main [] {
  print-header "ROLLBACK"
  notify "Flake Rollback" "Rolling back to previous generation..." "pending"
  nh os rollback
  notify "Flake Rollback" "Rollback complete" "success"
  print-header "END"
}

