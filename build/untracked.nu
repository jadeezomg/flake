#!/usr/bin/env nu
# List untracked files in the flake repo (parity with rh-untracked.sh)

use common.nu *

def main [] {
  print-header "UNTRACKED"
  let flake_path = (get-flake-path)

  notify "Flake Untracked" "Checking for untracked files..." "pending"

  let untracked = (git -C $flake_path ls-files --others --exclude-standard | lines | where ($it | is-not-empty))

  if ($untracked | is-empty) {
    notify "Flake Untracked" "Repository is clean. No untracked files." "success"
    return
  }

  let count = ($untracked | length)
  notify "Flake Untracked" $"Found ($count) untracked files. See terminal for list." "info"
  print ""

  $untracked | each { |file|
    let size = (^du -h $"($flake_path)/($file)" | complete)
    let size_display = (if $size.exit_code == 0 { $size.stdout | str trim | split row " " | get 0 } else { "?" })
    print $"  ($file) [($size_display)]"
  }

  print ""
  print-header "END"
}


