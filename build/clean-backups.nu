#!/usr/bin/env nu
# Clean backup files from config directory
# Usage: clean-backups.nu [--dry-run]

use common.nu *

def main [--dry-run] {
  let config_dir = $"($env.HOME)/.config"
  
  if $dry_run {
    notify "Flake Clean Backups" "Dry run: Scanning for backup files..." "pending"
  } else {
    notify "Flake Clean Backups" "Cleaning backup files..." "pending"
  }
  
  # Find backup files using nushell glob
  let backups = (glob $"($config_dir)/**/*.backup" | append (glob $"($config_dir)/**/*.bkp"))
  let count = ($backups | length)
  
  if $count == 0 {
    notify "Flake Clean Backups" "No backup files found" "success"
  } else {
    for file in $backups {
      if $dry_run {
        print $"Would remove: ($file)"
      } else {
        rm $file
        print $"Removed: ($file)"
      }
    }
    
    if $dry_run {
      notify "Flake Clean Backups" $"Would remove ($count) backup files" "info"
    } else {
      notify "Flake Clean Backups" $"Removed ($count) backup files" "success"
    }
  }
}
