#!/usr/bin/env nu
# System health check
# Usage: health.nu

use common.nu *
use theme.nu *

def check-flake-status [flake_path: string] {
  print-pending "Flake Status"
  
  let status_raw = (git -C $flake_path status --short | lines | where ($it | str trim | is-not-empty))
  let untracked = (git -C $flake_path ls-files --others --exclude-standard | lines | where ($it | is-not-empty))
  
  let tracked_count = ($status_raw | length)
  let untracked_count = ($untracked | length)
  
  if ($tracked_count == 0) and ($untracked_count == 0) {
    print $"  ($theme_icons.success) (ansi ($theme_colors.success))Working tree clean(ansi reset)"
  } else {
    if $tracked_count > 0 {
      print $"  ($theme_icons.pending) (ansi ($theme_colors.pending))($tracked_count) tracked changes(ansi reset)"
    }
    if $untracked_count > 0 {
      print $"  ($theme_icons.pending) (ansi ($theme_colors.pending))($untracked_count) untracked files(ansi reset)"
    }
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
  
  let info_output = (nh os info | lines)
  
  let table_start = ($info_output | enumerate | where { |row| 
    ($row.item | str contains "Generation No") or ($row.item | str contains "Generation")
  } | get 0? | get index? | default 0)
  
  let data_rows = ($info_output | skip ($table_start + 1) | where ($it | str trim | is-not-empty))
  
  let generations = ($data_rows | each { |line|
    let trimmed = ($line | str trim)
    let is_current = ($trimmed | str contains "(current)")
    let gen_match = ($trimmed | parse -r '(?P<gen>\d+)' | get 0? | get gen? | default "")
    let gen_num = (if ($gen_match | is-not-empty) { 
      try {
        ($gen_match | into int)
      } catch {
        null
      }
    } else { 
      null 
    })
    
    let date_match = ($trimmed | parse -r '(?P<date>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})' | get 0? | get date? | default "")
    let version_match = ($trimmed | parse -r '(?P<version>\d+\.\d+[^\s]*)' | get 0? | get version? | default "")
    
    if ($gen_num != null) {
      {
        gen: $gen_num
        current: $is_current
        date: $date_match
        version: $version_match
        raw: $trimmed
      }
    } else {
      null
    }
  } | where ($it != null))
  
  if ($generations | is-not-empty) {
    $generations | each { |gen|
      if $gen.current {
        let date_display = (if ($gen.date | is-not-empty) {
          ($gen.date | split row " " | get 0)
        } else {
          "unknown"
        })
        print $"  ($theme_icons.success) (ansi ($theme_colors.success_bold))Generation ($gen.gen)(ansi reset) (ansi ($theme_colors.success))\(current\)(ansi reset) - ($date_display)"
      } else {
        let date_display = (if ($gen.date | is-not-empty) {
          ($gen.date | split row " " | get 0)
        } else {
          "unknown"
        })
        print $"  ($theme_icons.info) (ansi ($theme_colors.info))Generation ($gen.gen)(ansi reset) - ($date_display)"
      }
    }
    
    let total = ($generations | length)
    let current_gen = ($generations | where { |g| $g.current } | get 0? | get gen? | default "?")
    print $"  ($theme_icons.info) (ansi ($theme_colors.info_bold))Total: ($total) generations(ansi reset) (ansi ($theme_colors.info))\(current: ($current_gen)\)(ansi reset)"
  } else {
    print $"  ($theme_icons.info) (ansi ($theme_colors.info))Unable to parse generations(ansi reset)"
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
  print-header "SYSTEM HEALTH"
  let flake_path = (get-flake-path)
  
  notify "Flake Health" "Running system health check..." "pending"
  
  check-flake-status $flake_path
  print ""
  
  check-disk-usage
  print ""
  
  check-generations
  print ""
  
  check-services
  print ""
  
  print-header "END"
  notify "Flake Health" "Health check complete" "success"
}