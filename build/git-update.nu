#!/usr/bin/env nu
# Show status/diff and push with a commit message prompt

use common.nu *

def main [] {
  let flake_path = (get-flake-path)
  let fmt_script = $"($flake_path)/build/fmt.nu"
  if ($fmt_script | path exists) {
    nu $fmt_script --no-tree | ignore
  }

  # Import theme for consistent colors and icons
  use theme.nu *

  print-header "GIT UPDATE"
  let repo = (get-flake-path)

  # Show recent commits
  print ""
  print-header "RECENT COMMITS"
  try {
    let log_output = (git -C $repo log --pretty=%h»¦«%s»¦«%aN»¦«%ad»¦«%ae -n 5 | lines)
    if ($log_output | is-not-empty) {
      $log_output
      | split column "»¦«" commit subject name date email
      | upsert date {|d| $d.date | into datetime | format date '%Y-%m-%d'}
      | group-by date
      | transpose date commits
      | each { |day|
          print-info $"($theme_icons.info) (ansi $theme_colors.pending_bold)($day.date)(ansi reset)"
          $day.commits | each { |commit|
            let short_commit = ($commit.commit | str substring 0..7)
            let short_subject = (if ($commit.subject | str length) > 60 {
              $"($commit.subject | str substring 0..57)..."
            } else {
              $commit.subject
            })
            print-info $"  (ansi $theme_colors.success)($short_commit)(ansi reset) ($short_subject) (ansi $theme_colors.info)($commit.name)(ansi reset)"
          }
        }
    } else {
      print-info "No commits found."
    }
  } catch { |err|
    print-info "Could not retrieve commit history."
  }
  print ""

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
    print ""

    # Group files by directory for better organization
    $untracked | sort | each { |file|
      let size_display = (get-file-size $"($repo)/($file)")

      # Color code file types using theme colors
      let color = if ($file | str ends-with ".nix") {
        $theme_colors.info_bold
      } else if ($file | str ends-with ".nu") {
        $theme_colors.success_bold
      } else if ($file | str ends-with ".lock") {
        $theme_colors.pending_bold
      } else {
        "blue_bold"
      }

      let size_color = if ($size_display | str contains "KB") {
        $theme_colors.pending
      } else if ($size_display | str contains "MB") {
        $theme_colors.error
      } else {
        $theme_colors.success
      }

      print-info $"  (ansi $color)($file)(ansi reset) (ansi $size_color)[($size_display)](ansi reset)"
    }
  }

  print ""
  print-header "DIFF STATS"
  let diff_stat = (git -C $repo diff --stat | lines)
  if ($diff_stat | is-not-empty) {
    $diff_stat | each { |line|
      if ($line | str contains "|") and ($line | str contains "+") and ($line | str contains "-") {
        # Parse diff stat lines like: file | 10 +++++----- | 5 files changed, 10 insertions(+), 5 deletions(-)
        let parts = ($line | split row "|")
        if ($parts | length) >= 2 {
          let file_part = ($parts | get 0 | str trim)
          let stats_part = ($parts | get 1 | str trim)

          # Extract numbers from the stats
          let insertions = if ($stats_part | str contains "+") {
            ($stats_part | split row "+" | where ($it | str contains "+") | str join "+" | str length)
          } else { 0 }
          let deletions = if ($stats_part | str contains "-") {
            ($stats_part | split row "-" | where ($it | str contains "-") | str join "-" | str length)
          } else { 0 }

          # Color code based on file type
          let file_color = if ($file_part | str ends-with ".nix") {
            $theme_colors.info_bold
          } else if ($file_part | str ends-with ".nu") {
            $theme_colors.success_bold
          } else {
            "blue_bold"
          }

          # Parse and color the stats part with separate colors for + and -
          let colored_stats = if ($stats_part | str contains "+") or ($stats_part | str contains "-") {
            # Find where the visual part starts (after the number)
            let visual_start = ($stats_part | str index-of '+')
            if $visual_start == -1 {
              let visual_start = ($stats_part | str index-of '-')
            }

            if $visual_start != -1 {
              let number_part = ($stats_part | str substring 0..$visual_start | str trim)
              let visual_part = ($stats_part | str substring $visual_start.. | str trim)

              # Color each character in the visual part
              let colored_visual = ($visual_part | split chars | each { |char|
                if $char == '+' {
                  $"(ansi $theme_colors.success_bold)($char)(ansi $theme_colors.success)"
                } else if $char == '-' {
                  $"(ansi $theme_colors.error_bold)($char)(ansi $theme_colors.error)"
                } else {
                  $char
                }
              } | str join '')

              $"($number_part) ($colored_visual)"
            } else {
              $stats_part
            }
          } else {
            $stats_part
          }

          print-info $"(ansi $file_color)($file_part)(ansi reset) | ($colored_stats)(ansi reset)"
        } else {
          print-info $line
        }
      } else {
        # Summary line or other lines
        if ($line | str contains "changed") or ($line | str contains "insertion") or ($line | str contains "deletion") {
          print-info $"(ansi $theme_colors.pending_bold)($line)(ansi reset)"
        } else {
          print-info $line
        }
      }
    }
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
    $commit_res.stdout | lines | each { |line|
      if ($line | str starts-with "[") and ($line | str contains " ") {
        # Commit summary line like: [main abc1234] Commit message
        let bracket_end = ($line | str index-of "]")
        if $bracket_end != -1 {
          let commit_info = ($line | str substring 0..($bracket_end + 1))
          let message = ($line | str substring ($bracket_end + 2)..)
          print-success $"(ansi $theme_colors.success_bold)($commit_info)(ansi reset) (ansi white_bold)($message)(ansi reset)"
        } else {
          print-success $line
        }
      } else {
        print-success $line
      }
    }
  }

  let show_res = (^git -C $repo --no-pager show --stat -1 | complete)
  if $show_res.exit_code == 0 {
    if ($show_res.stdout | is-not-empty) {
      print ""
      print-info $"($theme_icons.info) Commit details:"
      $show_res.stdout | lines | each { |line|
        if ($line | str starts-with "commit ") {
          let commit_hash = ($line | str substring 7..)
          print-info $"  (ansi $theme_colors.success)Commit:(ansi reset) (ansi $theme_colors.pending)($commit_hash)(ansi reset)"
        } else if ($line | str starts-with "Author: ") {
          let author = ($line | str substring 8..)
          print-info $"  (ansi $theme_colors.success)Author:(ansi reset) (ansi $theme_colors.info)($author)(ansi reset)"
        } else if ($line | str starts-with "Date: ") {
          let date = ($line | str substring 6..)
          print-info $"  (ansi $theme_colors.success)Date:(ansi reset) (ansi magenta)($date)(ansi reset)"
        } else if ($line | str trim | is-empty) {
          # Skip empty lines
        } else if ($line | str contains "|") and ($line | str contains "+") and ($line | str contains "-") {
          # Diff stat line
          let parts = ($line | split row "|")
          if ($parts | length) >= 2 {
            let file_part = ($parts | get 0 | str trim)
            let stats_part = ($parts | get 1 | str trim)
            print-info $"  (ansi blue)($file_part)(ansi reset) | (ansi $theme_colors.pending)($stats_part)(ansi reset)"
          } else {
            print-info $"  ($line)"
          }
        } else if ($line | str contains "changed") or ($line | str contains "insertion") or ($line | str contains "deletion") {
          print-info $"  (ansi $theme_colors.pending_bold)($line)(ansi reset)"
        } else {
          print-info $"  ($line)"
        }
      }
    }
  }

  let push_res = (^git -C $repo push | complete)
  if $push_res.exit_code == 0 {
    if ($push_res.stdout | is-not-empty) {
      print ""
      print-header "PUSH"
      $push_res.stdout | lines | each { |line|
        if ($line | str contains "->") and ($line | str contains "..") {
          # Push summary like: abc123..def456 main -> main
          let parts = ($line | split row " ")
          if ($parts | length) >= 4 {
            let range = ($parts | get 0)
            let arrow = ($parts | get 1)
            let branch_from = ($parts | get 2)
            let branch_to = ($parts | get 3)
            print-success $"($theme_icons.success) (ansi $theme_colors.success_bold)($range)(ansi reset) (ansi $theme_colors.info)($arrow)(ansi reset) (ansi $theme_colors.pending_bold)($branch_from)(ansi reset) → (ansi $theme_colors.success_bold)($branch_to)(ansi reset)"
          } else {
            print-success $"($theme_icons.success) ($line)"
          }
        } else if ($line | str starts-with "To ") {
          # Remote URL line
          let remote_url = ($line | str substring 3..)
          print-info $"($theme_icons.info) (ansi $theme_colors.info_bold)Remote:(ansi reset) (ansi cyan)($remote_url)(ansi reset)"
        } else {
          print-success $"($theme_icons.success) ($line)"
        }
      }
    }
  } else {
    notify "Flake Git" "Push failed" "error"
    print-error $"($theme_icons.error) Push failed:"
    print $push_res.stderr
    return
  }

  print ""
  print-header "POST-STATUS"
  let post_status = (git -C $repo status --short)
  if ($post_status | is-empty) {
    print-success $"($theme_icons.success) Working tree clean."
  } else {
    print-info $"($theme_icons.pending) Uncommitted changes remain:"
    $post_status | lines | where ($it | str trim | is-not-empty) | each { |line|
      let trimmed = ($line | str trim)

      # Parse git status short format: XY filename
      let status_code = ($trimmed | str substring 0..2 | str trim)
      let file_path = ($trimmed | str substring 2.. | str trim)

      # Color code based on status (same as initial status)
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

      print-info $"  (ansi $color)($status_padded)(ansi reset) ($file_path)"
    }
  }

  print-header "END"
  notify "Flake Git" "Git workflow complete" "success"
}
