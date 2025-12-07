#!/usr/bin/env nu
# Build and switch to NixOS configuration
# Usage: switch.nu <host> [--fast]

use common.nu *

def pre-flight-checks [flake_path: string] {
  notify "Flake Switch" "Running pre-flight checks..."
  let result = (nix flake check $flake_path --no-write-lock-file | complete)
  if $result.exit_code == 0 {
    notify "Flake Switch" "Flake validation passed"
  } else {
    notify "Flake Switch" "Warning: Flake validation failed [continuing anyway]"
  }
}

def post-build-tasks [fast, script_dir: string] {
  if not $fast {
    notify "Flake Switch" "Running post-build tasks..."
    
    # Update caches (except nix-index which is slow)
    nu $"($script_dir)/update-caches.nu" --all-except-nix
    
    # Source user vars (if they exist)
    # Note: source requires a constant path, so we use a workaround
    let user_vars_path = $"/etc/profiles/per-user/($env.USER)/etc/profile.d/hm-session-vars.sh"
    if ($user_vars_path | path exists) {
      # Source the file using nu -c
      nu -c $"source ($user_vars_path)"
    }
    
    notify "Flake Switch" "System rebuild complete"
  } else {
    notify "Flake Switch" "Fast rebuild complete"
  }
}

def main [host?: string, --fast] {
  let flake_path = (get-flake-path)
  let script_dir = ($nu.current-exe | path dirname)
  let target_host = (get-host $host)
  
  if not $fast {
    pre-flight-checks $flake_path
  } else {
    notify "Flake Switch" "Fast mode enabled - skipping pre/post checks"
  }
  
  notify "Flake Switch" $"Building and switching configuration for ($target_host)..."
  sudo nixos-rebuild switch --flake $"($flake_path)#($target_host)"
  
  post-build-tasks $fast $script_dir
}

