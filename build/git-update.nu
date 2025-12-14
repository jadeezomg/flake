#!/usr/bin/env nu
# Show status/diff and push with a commit message prompt

use common.nu *

def main [] {
  let flake_path = (get-flake-path)
  let fmt_script = $"($flake_path)/build/fmt.nu"
  if ($fmt_script | path exists) {
    nu $fmt_script --no-tree | ignore
  }
  
  print-header "GIT UPDATE"
  let repo = (get-flake-path)
  
  # Check for tracked changes
  let status_raw = (git -C $repo status --short)
  let status_lines = ($status_raw | lines | where ($it | str trim | is-not-empty))
  
  # Check for untracked files
  let untracked = (git -C $repo ls-files --others --exclude-standard | lines | where ($it | is-not-empty))
  
  # If nothing to commit, exit early
  if ($status_lines | is-empty) and ($untracked | is-empty) {
    print-info "Working tree clean. Nothing to commit."
    return
  }
  
  # Show tracked changes
  if ($status_lines | is-not-empty) {
    print-header "GIT STATUS"
    use theme.nu *
    
    $status_lines | each { |line|
      let trimmed = ($line | str trim)
      
      # Parse git status short format: XY filename
      # X = staged status, Y = unstaged status
      let status_code = ($trimmed | str substring 0..2 | str trim)
      let file_path = ($trimmed | str substring 2.. | str trim)
      
      # Color code based on status
      let has_m = ($status_code | str contains "M")
      let has_r = ($status_code | str contains "R")
      let color = (if ($status_code | str contains "D") {
        $theme_colors.error_bold
      } else if ($status_code | str contains "A") {
        $theme_colors.success_bold
      } else if ($has_m or $has_r) {
        $theme_colors.pending_bold
      } else {
        $theme_colors.info_bold
      })
      
      # Format status code (pad to 2 chars, replace spaces with middle dot)
      let status_padded = (if ($status_code | str length) == 1 {
        $"·($status_code)"
      } else {
        $status_code
      })
      
      print-info $"(ansi $color)($status_padded)(ansi reset) ($file_path)"
    }
  }
  
  # Show untracked files
  if ($untracked | is-not-empty) {
    print ""
    print-header "UNTRACKED FILES"
    let count = ($untracked | length)
    let file_word = (if $count == 1 { "file" } else { "files" })
    print-info $"Found ($count) untracked ($file_word):"
    $untracked | each { |file|
      let size_display = (get-file-size $"($repo)/($file)")
      print-info $"  ($file) [($size_display)]"
    }
  }

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
