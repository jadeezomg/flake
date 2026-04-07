# Find defaults domains that are likely user-configured
# This helps identify which domains to migrate to Nix

def main [] {
  print "Scanning for user-configured defaults domains..."
  print ""
  
  let domains = (defaults domains | split row "," | each {|d| $d | str trim})
  
  let user_domains = $domains | where {|domain|
    # Filter out system domains and focus on user-configurable ones
    not ($domain | str starts-with "com.apple.") or 
    ($domain | str contains "finder") or
    ($domain | str contains "dock") or
    ($domain | str contains "screencapture") or
    ($domain | str contains "safari") or
    ($domain | str contains "terminal") or
    ($domain | str contains "textinput")
  }
  
  # Also include third-party apps
  let third_party = $domains | where {|domain|
    not ($domain | str starts-with "com.apple.") and
    not ($domain | str starts-with "org.gnu.") and
    not ($domain | str starts-with "org.mozilla.") and
    not ($domain | str starts-with "com.google.") and
    not ($domain | str starts-with "com.microsoft.") and
    not ($domain | str starts-with "com.electron.") and
    not ($domain | str starts-with "com.todesktop.") and
    not ($domain | str starts-with "com.vanta.") and
    not ($domain | str starts-with "com.bresink.") and
    not ($domain | str starts-with "com.DanPristupov.") and
    not ($domain | str starts-with "com.mitchellh.") and
    not ($domain | str starts-with "com.mowglii.") and
    not ($domain | str starts-with "com.pilotmoon.") and
    not ($domain | str starts-with "com.lwouis.") and
    not ($domain | str starts-with "com.raycast.") and
    not ($domain | str starts-with "com.tinyspeck.") and
    not ($domain | str starts-with "com.todesktop.") and
    not ($domain | str starts-with "digital.twisted.") and
    not ($domain | str starts-with "art.ginzburg.") and
    not ($domain | str starts-with "dev.zed.") and
    not ($domain | str starts-with "notion.id") and
    not ($domain | str starts-with "org.filezilla-project.") and
    not ($domain | str starts-with "emacs") and
    not ($domain | str starts-with "app.zen-browser.")
  }
  
  print "=== User-configurable Apple domains ==="
  $user_domains | each {|d| print $"  ($d)"}
  
  print ""
  print "=== Third-party app domains ==="
  $third_party | each {|d| print $"  ($d)"}
  
  print ""
  print "To export a domain to Nix format:"
  print "  python3 build/read-defaults.py <domain>"
}

