#!/usr/bin/env nu
# Initialize flake configuration
# Usage: init.nu [host]
# If host is not provided, will attempt to auto-detect

use common.nu *

def main [host?: string] {
  print-header "INIT"
  let flake_path = (get-flake-path)
  
  # Determine which host to set
  let target_host = (
    if ($host | is-empty) {
      print-pending "Auto-detecting host from hostname..."
      let hostname = (get-current-host)
      print-info $"Current hostname: ($hostname)"
      let detected = (detect-host-from-hostname)
      
      if ($detected | is-empty) {
        print-error "Could not auto-detect host from hostname"
        print ""
        print-info "Available hosts:"
        print-table (get-available-hosts) --compact
        print ""
        print "Please specify: init.nu <host>"
        exit 1
      }
      
      $detected
    } else {
      $host
    }
  )
  
  # Check if a host is already set and ask for confirmation
  let config_file = $"($flake_path)/.flake-host"
  if ($config_file | path exists) {
    let current_host = (open $config_file | str trim)
    if ($current_host | is-not-empty) and ($current_host != $target_host) {
      print ""
      print-pending $"A host is already configured: ($current_host)"
      print-info $"Attempting to set host to: ($target_host)"
      print ""
      if not (confirm "Overwrite existing host configuration?") {
        print ""
        print-info "Host configuration unchanged."
        exit 0
      }
      print ""
    }
  }
  
  set-host $target_host
  
  print ""
  print-success "Flake initialized!"
  print-info $"Default host: (get-host)"
  print-info $"Flake path: ($flake_path)"
  print ""
  print-info "You can now use build scripts without specifying the host:"
  let commands_table = [
    { command: "flake-switch", description: "Switch to the configured host" }
    { command: "flake-build build", description: "Build the flake" }
    { command: "flake-health", description: "Check flake health status" }
  ]
  print-table $commands_table --no-index
  print-header "END"
}

