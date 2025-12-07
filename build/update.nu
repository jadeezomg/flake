#!/usr/bin/env nu
# Update flake inputs
# Usage: update.nu [input]

use common.nu *

def main [input?: string] {
  let flake_path = (get-flake-path)
  
  if ($input | is-empty) {
    notify "Flake Update" "Updating all flake inputs..."
    nix flake update --flake $flake_path
    notify "Flake Update" "Flake inputs updated. See terminal for details."
    
    print ""
    print "Input changes:"
    git -C $flake_path diff flake.lock
      | lines
      | where {|line| ($line | str starts-with "+") and (
          ($line | str contains "lastModified") or ($line | str contains "narHash")
        )
      }
      | take 10
  } else {
    notify "Flake Update" $"Updating input: ($input)..."
    nix flake update --update-input $input --flake $flake_path
    notify "Flake Update" $"Updated input: ($input)"
  }
}

