#!/usr/bin/env nu
# Update flake inputs
# Usage: update.nu [input]

use common.nu *

def main [input?: string, --pear] {
  print-header "UPDATE"
  let flake_path = (get-flake-path)
  let is_darwin = (is-darwin)
  let cmd_prefix = (if $is_darwin { "nh darwin" } else { "nh os" })

  if ($input | is-empty) {
    notify "Flake Update" "Updating all flake inputs..." "pending"
    ^bash -c $"($cmd_prefix) switch --update --dry"
    notify "Flake Update" "Flake inputs updated. See terminal for details." "success"
  } else {
    notify "Flake Update" $"Updating input: ($input)..." "pending"
    ^bash -c $"($cmd_prefix) switch --update-input $input --dry"
    notify "Flake Update" $"Updated input: ($input)" "success"
  }

  if $pear {
    notify "Package Update" "Updating Pear Desktop to latest version..." "pending"
    try {
      run-external "./packages/pear-desktop/update.sh"
      notify "Package Update" "Pear Desktop updated successfully" "success"
    } catch { |err|
      notify "Package Update" $"Failed to update Pear Desktop: ($err.msg)" "error"
    }
  }

  print-header "END"
}

