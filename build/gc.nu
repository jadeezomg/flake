#!/usr/bin/env nu
# Garbage collection for NixOS
# Usage: gc.nu <mode> [value]
# Modes:
#   keep [N]   – keep last N generations + current (default N=5)
#     e.g. flake gc keep 5
#   days [N]   – delete generations older than N days (default N=7)
#     e.g. flake gc days 14
#   all        – full GC (system profiles, nix store GC, plus trash cleanup)
#     e.g. flake gc all

use common.nu *

def gc-keep [keep_count: int = 5] {
  notify "Flake GC" $"Collecting garbage, keeping last ($keep_count) generations..." "pending"
  
  show-progress "Running garbage collection"
  nh clean all --keep $keep_count
  nh clean user --keep $keep_count
  clear-progress
  
  let new_total = (nh os info | lines | length)
  notify "Flake GC" $"Garbage collection complete\nRemaining generations: ($new_total)" "success"
}

def gc-days [days: int = 7] {
  notify "Flake GC" $"Collecting generations older than ($days) days..." "pending"
  show-progress $"Collecting garbage older than ($days) days"
  nh clean all --keep-since $"($days)d"
  nh clean user --keep-since $"($days)d"
  clear-progress
  notify "Flake GC" "Garbage collection complete" "success"
}

def gc-all [] {
  notify "Flake GC" "Cleaning Nix garbage..." "pending"
  show-progress "Running deep garbage collection"
  nh clean all
  nh clean user
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

def main [mode: string, value?: string] {
  print-header "GC"
  match $mode {
    "keep" => {
      let count = ($value | default "5" | into int)
      gc-keep $count
    }
    "days" => {
      let days = ($value | default "7" | into int)
      gc-days $days
    }
    "all" => gc-all
    _ => {
      print-error $"Unknown mode: ($mode)"
      print "Modes: keep [N], days [N], all"
      exit 1
    }
  }
  print-header "END"
}

