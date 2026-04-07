#!/usr/bin/env nu
# Garbage collection for NixOS and Darwin
# Usage: gc.nu <mode>
# Modes:
#   keep   – keep last N generations (will prompt for N)
#     e.g. flake gc keep
#   days   – delete generations older than N days (will prompt for N)
#     e.g. flake gc days
#   all    – full GC (system profiles, nix store GC, plus trash cleanup)
#     e.g. flake gc all

use common.nu *

def gc-keep [] {
  let keep_count_result = (prompt-number "How many generations to keep? (default: 5)")
  if ($keep_count_result == null) {
    print-info "Aborted."
    return
  }
  let keep_count = $keep_count_result
  
  notify "Flake GC" $"Collecting garbage, keeping last ($keep_count) generations..." "pending"
  show-progress "Running garbage collection"
  nh clean all --keep $keep_count
  clear-progress
  
  let current_system = get-current-host
  if ($current_system | str contains "nixos") {
    let new_total = (nh os info | lines | length)
    notify "Flake GC" $"Garbage collection complete\nRemaining generations: ($new_total)" "success"
  } else {
    notify "Flake GC" "Garbage collection complete" "success"
  }
}

def gc-days [] {
  let days_result = (prompt-number "Delete generations older than how many days? (default: 7)")
  if ($days_result == null) {
    print-info "Aborted."
    return
  }
  let days = $days_result
  
  notify "Flake GC" $"Collecting generations older than ($days) days..." "pending"
  show-progress $"Collecting garbage older than ($days) days"
  nh clean all --keep-since $"($days)d"
  clear-progress
  notify "Flake GC" "Garbage collection complete" "success"
}

def gc-all [] {
  notify "Flake GC" "Cleaning Nix garbage..." "pending"
  show-progress "Running deep garbage collection"
  nh clean all
  clear-progress
  
  notify "Flake GC" "Cleaning Trash..." "pending"
  show-progress "Cleaning trash directory"
  let trash = $"($env.XDG_DATA_HOME? | default $"($env.HOME)/.local/share")/Trash"
  if ($trash | path exists) {
    let trash_rm = (^rm -rf $trash | complete)
    if $trash_rm.exit_code != 0 {
      let trash_rm_sudo = (^sudo rm -rf $trash | complete)
      if $trash_rm_sudo.exit_code != 0 {
        let err = ($trash_rm_sudo.stderr | default $trash_rm.stderr | str trim)
        notify "Flake GC" $"Skipping trash cleanup (permission denied at: ($trash)). ($err)" "info"
      }
    }
  }
  clear-progress
  
  notify "Flake GC" "Garbage collection complete" "success"
}

def main [mode: string] {
  print-header "GC"
  match $mode {
    "keep" => gc-keep
    "days" => gc-days
    "all" => gc-all
    _ => {
      print-error $"Unknown mode: ($mode)"
      print "Modes: keep, days, all"
      exit 1
    }
  }
  print-header "END"
}

