#!/usr/bin/env nu
# Show status/diff and push with a commit message prompt

use common.nu *

def main [] {
  let repo = (get-flake-path)

  print-header "GIT STATUS"
  let status = (git -C $repo status --short)
  if ($status | is-empty) {
    print-info "Working tree clean. Nothing to commit."
    return
  }
  $status | each { |line| print $"  ($line)" }

  print ""
  print-header "DIFF STATS"
  git -C $repo diff --stat
  git -C $repo diff --shortstat
  print ""

  let msg = (input "Commit message (or 'abort' to cancel): " | str trim)
  let msg_lc = ($msg | str downcase)
  if ($msg | is-empty) or ($msg_lc == "abort") {
    print-info "Aborted."
    return
  }

  notify "Flake Git" "Staging changes..." "pending"
  git -C $repo add -A

  notify "Flake Git" "Committing changes..." "pending"
  let commit_res = (^git -C $repo commit -m $msg | complete)
  if $commit_res.exit_code != 0 {
    print-error "Commit failed:"
    print $commit_res.stderr
    return
  }

  notify "Flake Git" "Pushing..." "pending"
  let push_res = (^git -C $repo push | complete)
  if $push_res.exit_code == 0 {
    notify "Flake Git" "Push successful" "success"
  } else {
    print-error "Push failed:"
    print $push_res.stderr
  }
}


