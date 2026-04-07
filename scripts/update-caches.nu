#!/usr/bin/env nu
# Update various caches
# Usage: update-caches.nu [--all | --all-except-nix | --bat | --tldr | --icons | --nix]

use common.nu *

# Placeholder for fuzzel apps cache (not used)
def update-apps-cache [] {
  print-pending "Fuzzel apps cache (placeholder - not configured)"
  # TODO: Implement if fuzzel is added
}

# Placeholder for launcher cache (not used)
def update-launcher-cache [] {
  print-pending "Launcher cache (placeholder - not configured)"
  # TODO: Implement if launcher is added
}

# Placeholder for wallpapers cache (not used)
def update-wallpapers-cache [] {
  print-pending "Wallpapers cache (placeholder - not configured)"
  # TODO: Implement if wallpaper manager is added
}

def update-bat-cache [] {
  print-pending "Updating bat cache..."
  if (command-exists bat) {
    bat cache --build
    print-success "Bat cache updated"
  } else {
    print-error "bat not found"
  }
}

def update-tldr-cache [] {
  print-pending "Updating tldr cache..."
  if (command-exists tldr) {
    tldr --update
    print-success "TLDR cache updated"
  } else {
    print-error "tldr not found"
  }
}

def update-icons-cache [] {
  print-pending "Unicode icons cache (placeholder)"
  # TODO: Implement if needed
  print-info "Skipping icons cache"
}

def update-nix-index [] {
  print-pending "Updating nix index..."
  if (command-exists nix-index) {
    nix-index
    print-success "Nix index updated"
  } else {
    print-error "nix-index not found"
  }
}

def main [
  --all (-A)
  --all-except-nix (-e)
  --apps (-a)
  --launcher (-l)
  --wallpapers (-w)
  --bat (-b)
  --tldr (-t)
  --icons (-i)
  --nix (-n)
] {
  print-header "UPDATE CACHES"
  # Determine requested operations
  let ops = (
    if $all {
      ["apps" "launcher" "wallpapers" "bat" "tldr" "icons" "nix"]
    } else if $all_except_nix {
      ["apps" "launcher" "wallpapers" "bat" "tldr" "icons"]
    } else {
      []
        | append (if $apps { "apps" } else { null })
        | append (if $launcher { "launcher" } else { null })
        | append (if $wallpapers { "wallpapers" } else { null })
        | append (if $bat { "bat" } else { null })
        | append (if $tldr { "tldr" } else { null })
        | append (if $icons { "icons" } else { null })
        | append (if $nix { "nix" } else { null })
        | where { |x| $x != null }
    }
  )
  
  if ($ops | is-empty) {
    print "Usage: update-caches.nu [OPTIONS]"
    print ""
    print "OPTIONS:"
    print "  --all, -A              Update all caches"
    print "  --all-except-nix, -e    Update all caches except nix index"
    print "  --apps, -a              Update apps cache (placeholder)"
    print "  --launcher, -l           Update launcher cache (placeholder)"
    print "  --wallpapers, -w         Update wallpapers cache (placeholder)"
    print "  --bat, -b                Update bat syntax cache"
    print "  --tldr, -t               Update tldr pages cache"
    print "  --icons, -i              Update icons cache (placeholder)"
    print "  --nix, -n                Update nix index database"
    exit 1
  }
  
  let failed = ($ops | par-each { |op|
    match $op {
      "apps" => (try { update-apps-cache; null } catch { "apps" })
      "launcher" => (try { update-launcher-cache; null } catch { "launcher" })
      "wallpapers" => (try { update-wallpapers-cache; null } catch { "wallpapers" })
      "bat" => (try { update-bat-cache; null } catch { "bat" })
      "tldr" => (try { update-tldr-cache; null } catch { "tldr" })
      "icons" => (try { update-icons-cache; null } catch { "icons" })
      "nix" => (try { update-nix-index; null } catch { "nix" })
      _ => null
    }
  } | where { |x| $x != null })
  
  if ($failed | is-empty) {
    print-success "All cache operations completed successfully!"
  } else {
    print-error $"Some operations failed: ($failed | str join ', ')"
    exit 1
  }
  print-header "END"
}
