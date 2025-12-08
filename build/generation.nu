#!/usr/bin/env nu
# List and manage NixOS generations
# Usage: generation.nu [list|switch <num>|delete <num>]

use common.nu *

def list-generations [] {
  print-header "NIXOS GENERATIONS"
  
  # Parse generations into structured data for better formatting
  let generations = (sudo nix-env --list-generations -p /nix/var/nix/profiles/system | lines)
  
  let gen_table = ($generations | parse "{gen} {date} {path}" | each { |row|
    {
      Generation: $row.gen
      Date: $row.date
      Path: ($row.path | str trim)
    }
  })
  
  $gen_table | table --expand
}

def switch-generation [num: int] {
  notify "Flake Generation" $"Switching to generation ($num)..." "pending"
  sudo nix-env --switch-generation $num -p /nix/var/nix/profiles/system
  notify "Flake Generation" "Generation switch complete" "success"
}

def delete-generation [num: int] {
  notify "Flake Generation" $"Deleting generation ($num)..." "pending"
  sudo nix-env --delete-generations $num -p /nix/var/nix/profiles/system
  notify "Flake Generation" "Generation deleted" "success"
}

def main [action: string = "list", num?: int] {
  print-header "GENERATION"
  match $action {
    "list" => list-generations
    "switch" => {
      if ($num | is-empty) {
        print-error "Generation number required"
        exit 1
      }
      switch-generation $num
    }
    "delete" => {
      if ($num | is-empty) {
        print-error "Generation number required"
        exit 1
      }
      delete-generation $num
    }
    _ => {
      print-error $"Unknown action: ($action)"
      print "Actions: list, switch <num>, delete <num>"
      exit 1
    }
  }
  print-header "END"
}

