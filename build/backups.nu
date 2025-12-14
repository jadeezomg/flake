#!/usr/bin/env nu
# Check and clean backup files in config directory
# Usage: backups.nu [--clean] [--dry-run]

use common.nu *

def main [--clean, --dry-run] {
  print-header "BACKUPS"
  let config_dir = $"($env.HOME)/.config"
  
  # Find backup files using reusable function
  let backups = (find-backup-files $config_dir)
  let backup_count = ($backups | length)
  
  if $backup_count == 0 {
    notify "Flake Backups" "No backup files found" "success"
    print-header "END"
    return
  }
  
  # Always show the backup files table
  print ""
  notify "Flake Backups" "Scanning for backup files..." "pending"
  
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
  print ""
  
  # If --clean flag is set, remove the files
  if $clean {
    if $dry_run {
      notify "Flake Backups" "Dry run: Would remove backup files..." "pending"
    } else {
      notify "Flake Backups" "Cleaning backup files..." "pending"
    }
    
    for file in $backups {
      if $dry_run {
        print-info $"Would remove: ($file)"
      } else {
        rm $file
        print-success $"Removed: ($file)"
      }
    }
    
    print ""
    if $dry_run {
      notify "Flake Backups" $"Would remove ($backup_count) backup files" "info"
    } else {
      notify "Flake Backups" $"Removed ($backup_count) backup files" "success"
    }
  } else {
    print-info "Use --clean to remove these files, or --clean --dry-run to preview"
  }
  
  print-header "END"
}

