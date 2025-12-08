#!/usr/bin/env nu
# Initialize flake configuration
# Usage: init.nu [host]
# If host is not provided, will attempt to auto-detect

use common.nu *

def main [host?: string] {
  print-header "INIT"
  let flake_path = (get-flake-path)
  
  if ($host | is-empty) {
    print-pending "Auto-detecting host from hostname..."
    let hostname = (get-current-host)
    print-info $"Current hostname: ($hostname)"
    let detected = (
      if ($hostname | str contains "framework") { "framework" }
      else if ($hostname | str contains "desktop") { "desktop" }
      else if ($hostname | str contains "caya") { "caya" }
      else { null }
    )
    
    if ($detected | is-empty) {
      print-error "Could not auto-detect host from hostname"
      print ""
      print "Available hosts:"
      print "  - framework"
      print "  - desktop"
      print "  - caya"
      print ""
      print "Please specify: init.nu <host>"
      exit 1
    }
    
    set-host $detected
  } else {
    set-host $host
  }
  
  print ""
  print-success "Flake initialized!"
  print-info $"Default host: (get-host)"
  print-info $"Flake path: ($flake_path)"
  print ""
  print "You can now use build scripts without specifying the host:"
  print "  flake-switch"
  print "  flake-build build"
  print "  flake-health"
  print-header "END"
}

