#!/usr/bin/env nu
# System health check
# Usage: health.nu

use common.nu *
use theme.nu *

def check-flake-status [flake_path: string] {
  print-pending "Flake Status"
  
  let git_status = (git -C $flake_path status --porcelain | lines)
  let uncommitted = ($git_status | where { |line|
    let starts_m = ($line | str starts-with " M")
    let starts_mm = ($line | str starts-with "MM")
    let starts_a = ($line | str starts-with "A ")
    let starts_d = ($line | str starts-with "D ")
    $starts_m or $starts_mm or $starts_a or $starts_d
  })
  let untracked = ($git_status | where { |line| $line | str starts-with "??" })
  
  let uncommitted_count = ($uncommitted | length)
  let untracked_count = ($untracked | length)
  
  let status = [
    {
      item: "Uncommitted changes",
      value: (if $uncommitted_count == 0 { $"(ansi green)None(ansi reset)" } else { $"(ansi yellow)($uncommitted_count) files(ansi reset)" }),
      status: (if $uncommitted_count == 0 { "success" } else { "pending" })
    },
    {
      item: "Untracked files",
      value: (if $untracked_count == 0 { $"(ansi green)None(ansi reset)" } else { $"(ansi yellow)($untracked_count) files(ansi reset)" }),
      status: (if $untracked_count == 0 { "success" } else { "pending" })
    }
  ]
  
  $status | each { |row|
    let icon = (if $row.status == "success" { $theme_icons.success } else { $theme_icons.pending })
    print $"  ($icon) (ansi ($theme_colors.success_bold))($row.item):(ansi reset) ($row.value)"
  }
}

def check-disk-usage [] {
  print-pending "Disk Usage"
  
  # Check root partition usage (fast)
  let df_output = (^df -h / | lines | skip 1)
  let root_info = (if ($df_output | is-not-empty) {
    let df_line = ($df_output | get 0)
    let df_parts = ($df_line | split row " " | where ($it | str length) > 0)
    if ($df_parts | length) >= 5 {
      let root_usage = ($df_parts | get 4)
      {
        item: "Root partition"
        value: $"($root_usage) used"
        status: "info"
      }
    } else {
      null
    }
  } else {
    null
  })
  
  # Nix store size (can be slow)
  let nix_store_raw = (run-external-with-status "Calculating Nix store size" "du -sh /nix/store")
  
  # Show result
  let nix_info = (if ($nix_store_raw | str trim | str length) > 0 {
    let size = ($nix_store_raw | str trim | split row " " | get 0)
    {
      item: "Nix store"
      value: $size
      status: "info"
    }
  } else {
    {
      item: "Nix store"
      value: "(calculation skipped or timed out)"
      status: "pending"
    }
  })
  
  let disk_info = ([$root_info $nix_info] | where ($it != null))
  
  $disk_info | each { |row|
    let icon = (if $row.status == "info" { $theme_icons.info } else { $theme_icons.pending })
    print $"  ($icon) (ansi ($theme_colors.info_bold))($row.item):(ansi reset) ($row.value)"
  }
}

def check-generations [] {
  print-pending "Generations"
  
  let generations_output = (sudo nix-env --list-generations -p /nix/var/nix/profiles/system | lines)
  let total = ($generations_output | length)
  
  # Parse current generation from the last line
  let current_line = ($generations_output | last)
  let current = (if ($current_line | str length) > 0 {
    let parts = ($current_line | split row " " | where ($it | str length) > 0)
    if ($parts | length) > 0 {
      $parts | get 0
    } else {
      "unknown"
    }
  } else {
    "unknown"
  })
  
  let gen_info = [
    {
      item: "Current generation",
      value: $"(ansi cyan_bold)($current)(ansi reset)",
      status: "info"
    },
    {
      item: "Total generations",
      value: $"(ansi cyan_bold)($total)(ansi reset)",
      status: "info"
    }
  ]
  
  $gen_info | each { |row|
    print $"  ($theme_icons.info) (ansi ($theme_colors.info_bold))($row.item):(ansi reset) ($row.value)"
  }
}

def check-services [] {
  print-pending "User Services"
  
  # Check common user services
  let services = ["dunst" "swaybg" "waybar"]
  let service_status = ($services | each { |service|
    let status = (^systemctl --user is-active $"($service).service" | complete)
    {
      service: $service
      active: ($status.exit_code == 0)
    }
  })
  
  $service_status | each { |svc|
    let icon = (if $svc.active { $theme_icons.success } else { $theme_icons.error })
    let status_text = (if $svc.active { $"(ansi ($theme_colors.success))active(ansi reset)" } else { $"(ansi ($theme_colors.error))inactive(ansi reset)" })
    let label_color = (if $svc.active { $theme_colors.success_bold } else { $theme_colors.error_bold })
    print $"  ($icon) (ansi ($label_color))($svc.service):(ansi reset) ($status_text)"
  }
}

def main [] {
  let flake_path = (get-flake-path)
  
  notify "Flake Health" "Running system health check..."
  print-header "SYSTEM HEALTH"
  
  check-flake-status $flake_path
  print ""
  
  check-disk-usage
  print ""
  
  check-generations
  print ""
  
  check-services
  print ""
  
  print-header "END"
}