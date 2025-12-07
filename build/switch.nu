#!/usr/bin/env nu
# Build and switch to NixOS configuration
# Usage: switch.nu <host> [--fast]

use common.nu *
use theme.nu *

def pre-flight-checks [flake_path: string] {
  notify "Flake Switch" "Running pre-flight checks..." "pending"
  let cmd = $"nix flake check ($flake_path) --no-write-lock-file"
  let cmd_pretty = $"(ansi ($theme_colors.info_bold))nix flake check(ansi reset) (ansi white)($flake_path)(ansi reset) (ansi ($theme_colors.pending_bold))--no-write-lock-file(ansi reset)"
  print-info $"(ansi ($theme_colors.info_bold))→(ansi reset) ($cmd_pretty)"
  let result = (^bash -lc $cmd | complete)
  if $result.exit_code == 0 {
    notify "Flake Switch" "Flake validation passed" "success"
  } else {
    notify "Flake Switch" "Warning: Flake validation failed [continuing anyway]" "pending"
  }
  print ""
}

def post-build-tasks [fast, script_dir: string] {
  if not $fast {
    notify "Flake Switch" "Running post-build tasks..." "pending"
    
    # Update caches (except nix-index which is slow)
    print-info $"→ nu ($script_dir)/update-caches.nu --all-except-nix"
    nu $"($script_dir)/update-caches.nu" --all-except-nix
    
    # Source user vars (if they exist)
    # Note: source requires a constant path, so we use a workaround
    let user_vars_path = $"/etc/profiles/per-user/($env.USER)/etc/profile.d/hm-session-vars.sh"
    if ($user_vars_path | path exists) {
      print-info $"→ source ($user_vars_path)"
      ^bash -lc $"source '$user_vars_path'"
    }
    
    notify "Flake Switch" "System rebuild complete" "success"
  } else {
    notify "Flake Switch" "Fast rebuild complete" "success"
  }
  print ""
}

def main [host?: string, --fast] {
  let flake_path = (get-flake-path)
  let script_dir = $"($flake_path)/build"
  let target_host = (get-host $host)
  
  if not $fast {
    pre-flight-checks $flake_path
  } else {
    notify "Flake Switch" "Fast mode enabled - skipping pre/post checks" "info"
    print ""
  }
  
  notify "Flake Switch" $"Building and switching configuration for ($target_host)..." "pending"
  let switch_cmd = $"sudo nixos-rebuild switch --flake '($flake_path)#($target_host)'"
  print-info $"→ ($switch_cmd)"
  ^bash -lc $switch_cmd
  print ""
  
  post-build-tasks $fast $script_dir
}

