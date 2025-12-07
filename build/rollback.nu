#!/usr/bin/env nu
# Rollback to previous NixOS generation
# Usage: rollback.nu

use common.nu *

def main [] {
  notify "Flake Rollback" "Rolling back to previous generation..."
  sudo nixos-rebuild switch --rollback
  notify "Flake Rollback" "Rollback complete"
}

