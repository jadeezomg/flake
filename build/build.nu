#!/usr/bin/env nu
# Build NixOS configuration without switching
# Usage: build.nu <host> <mode>
# Modes: build, boot, dry, dev

use common.nu *

def main [host?: string, mode: string = "build"] {
  let flake_path = (get-flake-path)
  let target_host = (get-host $host)
  
  match $mode {
    "build" => {
      notify "Flake Build" $"Building configuration for ($target_host)..." "pending"
      let cmd = $"cd /tmp && sudo nixos-rebuild build --flake '($flake_path)#($target_host)'"
      print-info $"→ ($cmd)"
      ^bash -c $cmd
      notify "Flake Build" "Build successful [not activated]" "success"
    }
    "boot" => {
      notify "Flake Build" $"Building boot configuration for ($target_host)..." "pending"
      let cmd = $"cd /tmp && sudo nixos-rebuild boot --flake '($flake_path)#($target_host)'"
      print-info $"→ ($cmd)"
      ^bash -c $cmd
      notify "Flake Build" "Will boot into new generation on next reboot" "success"
    }
    "dry" => {
      notify "Flake Build" $"Dry run for ($target_host)..." "pending"
      let cmd = $"cd /tmp && sudo nixos-rebuild dry-build --flake '($flake_path)#($target_host)'"
      print-info $"→ ($cmd)"
      ^bash -c $cmd
    }
    "dev" => {
      notify "Flake Build" $"Development build with trace output for ($target_host)" "pending"
      let cmd = $"cd /tmp && sudo nixos-rebuild switch --flake '($flake_path)#($target_host)' --show-trace -L"
      print-info $"→ ($cmd)"
      ^bash -c $cmd
    }
    _ => {
      print-error $"Invalid mode: ($mode)"
      print "Modes: build, boot, dry, dev"
      exit 1
    }
  }
}

