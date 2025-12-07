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
  notify "Flake GC" "Analyzing generations..." "pending"
  
  show-progress "Analyzing generations"
  let generations = (sudo nix-env --list-generations -p /nix/var/nix/profiles/system | lines)
  clear-progress
  
  let gen_nums = (
    $generations
    | where { |line| ($line | str trim) != "" }
    | parse "{gen} *"
    | get gen
    | into int
  )

  if ($gen_nums | is-empty) {
    notify "Flake GC" "No generations found to collect" "info"
    return
  }

  let current_gen = ($gen_nums | last)
  let total_gens = ($gen_nums | length)
  let gens_to_keep = ($keep_count + 1)
  
  if $total_gens <= $gens_to_keep {
    notify "Flake GC" "Nothing to collect [already at or below target]" "info"
    return
  }
  
  notify "Flake GC" $"Collecting garbage, keeping last ($keep_count) generations..." "pending"
  let keep_from = ($current_gen - $keep_count)
  
  # Animate spinner while deleting generations
  let gens_to_delete = ($generations | parse "{gen} {date} {path}" | get gen | into int | where { |gen| $gen < $keep_from and $gen != $current_gen })
  
  if ($gens_to_delete | length) > 0 {
    let gens_list = ($gens_to_delete | enumerate)
    for $item in $gens_list {
      let frame = ($item.index mod 10)
      let count = ($item.index + 1)
      let total = ($gens_list | length)
      show-progress $"Deleting generation ($item.item) [($count)/($total)]" --frame $frame
      sudo nix-env --delete-generations ($item.item) -p /nix/var/nix/profiles/system | ignore
    }
  }
  clear-progress
  
  show-progress "Running garbage collection"
  sudo nix-collect-garbage
  nix-collect-garbage
  clear-progress
  
  let new_total = (sudo nix-env --list-generations -p /nix/var/nix/profiles/system | lines | length)
  notify "Flake GC" $"Garbage collection complete\nRemaining generations: ($new_total)" "success"
}

def gc-days [days: int = 7] {
  notify "Flake GC" $"Collecting generations older than ($days) days..." "pending"
  show-progress $"Collecting garbage older than ($days) days"
  sudo nix-collect-garbage --delete-older-than $"($days)d"
  nix-collect-garbage --delete-older-than $"($days)d"
  clear-progress
  notify "Flake GC" "Garbage collection complete" "success"
}

def gc-all [] {
  notify "Flake GC" "Cleaning Nix garbage..." "pending"
  show-progress "Running deep garbage collection"
  sudo nix-collect-garbage -d
  nix-collect-garbage -d
  clear-progress
  
  notify "Flake GC" "Cleaning Trash..." "pending"
  show-progress "Cleaning trash directory"
  let trash = $"($env.XDG_DATA_HOME? | default $"($env.HOME)/.local/share")/Trash"
  if ($trash | path exists) {
    try {
      rm -rf $trash
    } catch {
      # If trash can't be removed as user, attempt with sudo. If that fails, inform and continue.
      try {
        sudo rm -rf $trash
      } catch {
        notify "Flake GC" $"Skipping trash cleanup (permission denied at: ($trash))" "info"
      }
    }
  }
  clear-progress
  
  notify "Flake GC" "Garbage collection complete" "success"
}

def main [mode: string, value?: string] {
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
}

