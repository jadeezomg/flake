#!/usr/bin/env nu
# Check for backup files in config directory
# Usage: check-backups.nu

use common.nu *

def main [] {
  notify "Flake Check Backups" "Scanning for backup files..."
  print ""
  
  let config_dir = $"($env.HOME)/.config"
  
  # Find backup files using nushell glob
  let backups = (glob $"($config_dir)/**/*.backup" | append (glob $"($config_dir)/**/*.bkp"))
  let backup_count = ($backups | length)
  
  if $backup_count == 0 {
    notify "Flake Check Backups" "No backup files found"
  } else {
    # Use structured data for better table formatting
    let backup_table = ($backups | each { |file|
      let size_result = (^du -h $file | complete)
      let size = if $size_result.exit_code == 0 {
        ($size_result.stdout | str trim | split row " " | get 0)
      } else {
        "unknown"
      }
      
      let file_info = (($file | path expand) | get metadata)
      let mtime = ($file_info.modified | into int)
      let now = (date now | into int)
      let age_days = (($now - $mtime) / 86400000000000)
      
      let rel_path = ($file | str replace $config_dir "")
      
      {
        File: $rel_path
        Size: $size
        Age: $"($age_days) days"
      }
    })
    
    $backup_table | table
    print ""
    print-info $"Total: ($backup_count) backup files"
  }
}
