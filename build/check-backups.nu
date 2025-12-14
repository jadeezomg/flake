#!/usr/bin/env nu
# Check for backup files in config directory
# Usage: check-backups.nu

use common.nu *

def main [] {
  print-header "CHECK BACKUPS"
  notify "Flake Check Backups" "Scanning for backup files..." "pending"
  print ""
  
  let config_dir = $"($env.HOME)/.config"
  
  # Find backup files using reusable function
  let backups = (find-backup-files $config_dir)
  let backup_count = ($backups | length)
  
  if $backup_count == 0 {
    notify "Flake Check Backups" "No backup files found" "success"
  } else {
    # Use structured data for better table formatting
    let backup_table = ($backups | each { |file|
      let rel_path = ($file | str replace $config_dir "")
      
      {
        File: $rel_path
        Size: (get-file-size $file)
        Age: $"((get-file-age-days $file)) days"
      }
    })
    
    $backup_table | table
    print ""
    print-info $"Total: ($backup_count) backup files"
  }
  print-header "END"
}
