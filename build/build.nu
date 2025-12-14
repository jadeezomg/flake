#!/usr/bin/env nu
# Build NixOS configuration without switching
# Usage: build.nu [host] [mode]
# Modes: build, boot, dry, dev

use common.nu *
use theme.nu *

def main [host_or_mode?: string, mode?: string] {
  print-header "BUILD"
  let flake_path = (get-flake-path)
  let modes = ["build" "boot" "dry" "dev"]

  let candidate = ($host_or_mode | default "")
  let is_mode_first = ($modes | any { |m| $m == $candidate })
  let selected_mode = (
    if $is_mode_first { $host_or_mode }
    else { $mode | default "build" }
  )

  let modes_txt = ($modes | str join ", ")
  if (not ($modes | any { |m| $m == $selected_mode })) {
    print-error $"Invalid mode: ($selected_mode)"
    print $"Modes: ($modes_txt)"
    exit 1
  }

  let target_host = (if $is_mode_first { get-host "" } else { get-host $host_or_mode })
  
  match $selected_mode {
    "build" => {
      notify "Flake Build" $"Building configuration for ($target_host)..." "pending"
      let cmd = (build-nixos-rebuild-cmd $flake_path $target_host "build")
      print-info $"(ansi ($theme_colors.info_bold))→(ansi reset) ($cmd)"
      ^bash -c $cmd
      notify "Flake Build" "Build successful [not activated]" "success"
    }
    "boot" => {
      notify "Flake Build" $"Building boot configuration for ($target_host)..." "pending"
      let cmd = (build-nixos-rebuild-cmd $flake_path $target_host "boot")
      print-info $"(ansi ($theme_colors.info_bold))→(ansi reset) ($cmd)"
      ^bash -c $cmd
      notify "Flake Build" "Will boot into new generation on next reboot" "success"
    }
    "dry" => {
      notify "Flake Build" $"Dry run for ($target_host)..." "pending"
      let cmd = (build-nixos-rebuild-cmd $flake_path $target_host "dry-build")
      print-info $"(ansi ($theme_colors.info_bold))→(ansi reset) ($cmd)"
      ^bash -c $cmd
    }
    "dev" => {
      notify "Flake Build" $"Development build with trace output for ($target_host)" "pending"
      let cmd = (build-nixos-rebuild-cmd $flake_path $target_host "dev")
      print-info $"(ansi ($theme_colors.info_bold))→(ansi reset) ($cmd)"
      ^bash -c $cmd
    }
    _ => {
      print-error $"Invalid mode: ($selected_mode)"
      print $"Modes: ($modes_txt)"
      exit 1
    }
  }
  print-header "END"
}

