#!/usr/bin/env nu
# Show status/diff and push with a commit message prompt

use common.nu *

def main [] {
  print-header "GIT UPDATE"
  let repo = (get-flake-path)
  let status = (git -C $repo status --short)
  if ($status | is-empty) {
    print-info "Working tree clean. Nothing to commit."
    return
  }
  $status | each { |line| print-info $"  ($line)" }

  print ""
  print-header "DIFF STATS"
  let diff_stat = (git -C $repo diff --stat | lines)
  if ($diff_stat | is-not-empty) {
    $diff_stat | each { |line| print-info $line }
  }
  print ""

  let msg = (input "Commit message (or 'abort' to cancel): " | str trim)
  let msg_lc = ($msg | str downcase)
  if ($msg | is-empty) or ($msg_lc == "abort") {
    print-info "Aborted."
    return
  }

  notify "Flake Git" "Running git workflow..." "pending"
  git -C $repo add -A

  let commit_res = (^git -C $repo commit -m $msg | complete)
  if $commit_res.exit_code != 0 {
    notify "Flake Git" "Commit failed" "error"
    print-error "Commit failed:"
    print $commit_res.stderr
    return
  }
  print ""
  print-header "COMMIT"
  if ($commit_res.stdout | is-not-empty) {
    $commit_res.stdout | lines | each { |line| print-success $line }
  }
  let show_res = (^git -C $repo --no-pager show --stat -1 | complete)
  if $show_res.exit_code == 0 {
    if ($show_res.stdout | is-not-empty) {
      $show_res.stdout | lines | each { |line| print-info $line }
    }
  }

  let push_res = (^git -C $repo push | complete)
  if $push_res.exit_code == 0 {
    if ($push_res.stdout | is-not-empty) {
      print ""
      print-header "PUSH"
      $push_res.stdout | lines | each { |line| print-success $line }
    }
  } else {
    notify "Flake Git" "Push failed" "error"
    print-error "Push failed:"
    print $push_res.stderr
    return
  }

  print ""
  print-header "POST-STATUS"
  let post_status = (git -C $repo status --short)
  if ($post_status | is-empty) {
    print-success "Working tree clean."
  } else {
    $post_status | each { |line| print-info $"  ($line)" }
  }

  print-header "END"
  notify "Flake Git" "Git workflow complete" "success"
}
