#!/usr/bin/env nu

# Script to run garbage collection on Darwin systems
# Usage: ./gc-darwin.nu [--dry] [--delete-older-than DAYS]

use common.nu *

def main [
  --dry  # Show what would be deleted without actually deleting
  delete_older_than: string = "30d"  # Delete generations older than this
] {
  print-header "DARWIN GARBAGE COLLECTION"

  # Check if we're on Darwin
  let current_system = get-current-host
  if not ($current_system | str contains "darwin") {
    print-error $"This script is for Darwin systems only. Current system: ($current_system)"
    exit 1
  }

  print-info $"Running garbage collection on Darwin system: ($current_system)"

  # Show current nix store stats
  print-pending "Current Nix store status:"
  let du_result = (^du -sh /nix/store | complete)
  if $du_result.exit_code == 0 {
    print-info $"Store size: ($du_result.stdout | str trim)"
  }

  let roots_result = (^nix store gc --print-roots | complete)
  if $roots_result.exit_code == 0 {
    let roots_count = ($roots_result.stdout | lines | length)
    print-info $"Roots: ($roots_count)"
  }

  # Build gc command
  let gc_args = if $dry {
    ["--dry-run", $"--delete-older-than=($delete_older_than)"]
  } else {
    [$"--delete-older-than=($delete_older_than)"]
  }

  let action = if $dry { "DRY RUN" } else { "COLLECTING GARBAGE" }
  print-pending $"($action) - deleting generations older than ($delete_older_than)"

  # Run garbage collection
  let start_time = date now
  let gc_result = (^nix-collect-garbage ...$gc_args | complete)

  let end_time = date now
  let duration = (($end_time - $start_time) | into int) / 1_000_000_000 | math round

  if $gc_result.exit_code == 0 {
    print-success $"Garbage collection completed successfully in ($duration)s"

    # Show stats after cleanup
    if not $dry {
      print-pending "Post-cleanup status:"
      let du_result = (^du -sh /nix/store | complete)
      if $du_result.exit_code == 0 {
        print-info $"Store size: ($du_result.stdout | str trim)"
      }
    }
  } else {
    print-error $"Garbage collection failed with exit code ($gc_result.exit_code)"
    if ($gc_result.stderr | str length) > 0 {
      print $gc_result.stderr
    }
  }

  # Additional Darwin-specific cleanup suggestions
  print ""
  print-info "Darwin-specific cleanup suggestions:"
  print-info "• Consider running: nix-store --optimise (deduplicates store)"
  print-info "• Check Homebrew: brew cleanup"
  print-info "• Clear caches: nix-collect-garbage -d (deletes all old generations)"

  print-header "END"
}
