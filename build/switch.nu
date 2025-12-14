#!/usr/bin/env nu
# Build and switch to NixOS configuration
# Usage: switch.nu <host> [--fast] [--check]

use common.nu *
use theme.nu *

def check [flake_path: string] {
  notify "Flake Switch" "Running pre-flight checks..." "pending"
  let cmd = $"nix flake check --all-systems ($flake_path) --no-write-lock-file"
  let cmd_pretty = $"(ansi ($theme_colors.info_bold))nix flake check --all-systems(ansi reset) (ansi white)($flake_path)(ansi reset) (ansi ($theme_colors.pending_bold))--no-write-lock-file(ansi reset)"
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
    print-info $"(ansi ($theme_colors.info_bold))→(ansi reset) nu ($script_dir)/update-caches.nu --all-except-nix"
    nu $"($script_dir)/update-caches.nu" --all-except-nix
    
    # Source user vars (if they exist)
    # Note: source requires a constant path, so we use a workaround
    let user_vars_path = $"/etc/profiles/per-user/($env.USER)/etc/profile.d/hm-session-vars.sh"
    if ($user_vars_path | path exists) {
      print-info $"(ansi ($theme_colors.info_bold))→(ansi reset) source ($user_vars_path)"
      ^bash -lc $"source '($user_vars_path)'"
    }
    
    notify "Flake Switch" "System rebuild complete" "success"
  } else {
    notify "Flake Switch" "Fast rebuild complete" "success"
  }
  print ""
}

def main [host?: string, --fast, --check, --skip-git, --override-input: string] {
  print-header "SWITCH"
  let flake_path = (get-flake-path)
  let script_dir = $"($flake_path)/build"
  let target_host = (get-host $host)
  
  # Run git update first (unless skipped or in fast mode)
  if not $fast and not $skip_git {
    let git_script = $"($script_dir)/git-update.nu"
    nu $git_script
    print ""
  } else if $fast {
    notify "Flake Switch" "Fast mode enabled - skipping git update and pre/post checks" "info"
    print ""
  }
  
  if not $fast {
    check $flake_path
  }

  # Allow running only the check and exit early
  if $check {
    notify "Flake Switch" "Check-only flag set; skipping rebuild" "info"
    print ""
    print-header "END"
    return
  }
  
  notify "Flake Switch" $"Building and switching configuration for ($target_host)..." "pending"
  let switch_cmd = if ($override_input | is-not-empty) {
    $"sudo nixos-rebuild switch --flake '($flake_path)#($target_host)' --override-input ($override_input)"
  } else {
    (build-nixos-rebuild-cmd $flake_path $target_host "switch")
  }
  print-info $"(ansi ($theme_colors.info_bold))→(ansi reset) ($switch_cmd)"
  ^bash -lc $switch_cmd
  print ""
  
  post-build-tasks $fast $script_dir
  print-header "END"
}

