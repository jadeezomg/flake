#!/usr/bin/env nu
# List and manage NixOS generations
# Usage: generation.nu [list|switch [num]|delete [num]]

use common.nu *

def list-generations [] {
  let is_darwin = (is-darwin)
  let header = (if $is_darwin { "DARWIN GENERATIONS" } else { "NIXOS GENERATIONS" })
  print-header $header
  
  if $is_darwin {
    # Darwin doesn't have nh darwin info, use darwin-rebuild instead
    print-info "Darwin generation listing not yet supported via nh. Use 'darwin-rebuild --list-generations' directly."
    print ""
    let generations = (^darwin-rebuild --list-generations | complete)
    if $generations.exit_code == 0 {
      print $generations.stdout
    } else {
      print-error "Failed to list generations"
    }
  } else {
    let generations = nh os info
    print $generations
  }
}

def switch-generation [num: int] {
  let is_darwin = (is-darwin)
  notify "Flake Generation" $"Switching to generation ($num)..." "pending"
  
  if $is_darwin {
    # Darwin doesn't have nh darwin rollback, use darwin-rebuild instead
    let result = (^darwin-rebuild switch --rollback-to $num | complete)
    if $result.exit_code == 0 {
      notify "Flake Generation" "Generation switch complete" "success"
    } else {
      notify "Flake Generation" $"Failed to switch generation: ($result.stderr)" "error"
    }
  } else {
    nh os rollback --to $num
    notify "Flake Generation" "Generation switch complete" "success"
  }
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
      list-generations
      print ""
      
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
      list-generations
      print ""
      
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

