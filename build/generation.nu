#!/usr/bin/env nu
# List and manage NixOS generations
# Usage: generation.nu [list|switch [num]|delete [num]]

use common.nu *

def list-generations [] {
  print-header "NIXOS GENERATIONS"
  
  # Parse generations into structured data for better formatting
  let generations = sudo nix-env --profile /nix/var/nix/profiles/system --list-generations
  
  print $generations
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
  match $action {
    "list" => list-generations
    "switch" => {
      # Show all generations first
      list-generations
      print ""
      
      # Prompt for generation number if not provided
      let gen_num = if ($num | is-empty) {
        let result = (prompt-number "Enter generation number to switch to")
        if ($result == null) {
          return
        }
        $result
      } else {
        $num
      }
      
      switch-generation $gen_num
    }
    "delete" => {
      # Show all generations first
      list-generations
      print ""
      
      # Prompt for generation number if not provided
      let gen_num = if ($num | is-empty) {
        let result = (prompt-number "Enter generation number to delete")
        if ($result == null) {
          return
        }
        $result
      } else {
        $num
      }
      
      delete-generation $gen_num
    }
    _ => {
      print-error $"Unknown action: ($action)"
      print "Actions: list, switch [num], delete [num]"
      exit 1
    }
  }
  print-header "END"
}

