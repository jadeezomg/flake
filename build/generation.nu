#!/usr/bin/env nu
# List and manage NixOS generations
d# Usage: generation.nu [list|bootloader|switch [num]|delete [num]]

use common.nu *

def list-generations [] {
  let is_darwin = (is-darwin)
  let header = (if $is_darwin { "DARWIN GENERATIONS" } else { "NIXOS GENERATIONS" })
  print-header $header
  
  if $is_darwin {
    # Darwin doesn't have nh darwin info, use darwin-rebuild instead
    print-info "Darwin generation listing not yet supported via nh. Use 'darwin-rebuild --list-generations' directly."
    print ""
    let generations = (^darwin-rebuild --list-generations | complete)
    if $generations.exit_code == 0 {
      print $generations.stdout
    } else {
      print-error "Failed to list generations"
    }
  } else {
    let generations = nh os info
    print $generations
  }
}

def list-bootloader-entries [] {
  let is_darwin = (is-darwin)
  if $is_darwin {
    print-error "Bootloader entries are not applicable on Darwin"
    return
  }
  
  print-header "BOOTLOADER ENTRIES"
  
  # Try bootctl list first (works for systemd-boot and some EFI setups)
  let bootctl_result = (^bootctl list 2>/dev/null | complete)
  if $bootctl_result.exit_code == 0 and ($bootctl_result.stdout | str trim | is-not-empty) {
    print $bootctl_result.stdout
    print ""
  }
  
  # Check EFI directory for Lanzaboote entries
  let efi_path = "/boot/efi/EFI/Linux"
  if ($efi_path | path exists) {
    print-info "Lanzaboote entries in /boot/efi/EFI/Linux:"
    try {
      let entries = (ls $efi_path | to text)
      print $entries
    } catch {
      print-info "No entries found or cannot access EFI directory"
    }
  } else {
    # Try alternative EFI paths
    let alt_paths = ["/boot/EFI/Linux", "/efi/EFI/Linux"]
    mut found = false
    for path in $alt_paths {
      if ($path | path exists) {
        print-info $"Lanzaboote entries in ($path):"
        try {
          let entries = (ls $path | to text)
          print $entries
          $found = true
          break
        } catch {
          # Continue to next path
        }
      }
    }
    if not $found {
      print-info "No EFI/Linux directory found. Bootloader entries may be managed differently."
    }
  }
  
  # Also show EFI boot entries using efibootmgr if available
  let efibootmgr_result = (^efibootmgr -v 2>/dev/null | complete)
  if $efibootmgr_result.exit_code == 0 and ($efibootmgr_result.stdout | str trim | is-not-empty) {
    print ""
    print-info "EFI Boot Manager entries:"
    print $efibootmgr_result.stdout
  }
}

def switch-generation [num: int] {
  let is_darwin = (is-darwin)
  notify "Flake Generation" $"Switching to generation ($num)..." "pending"
  
  if $is_darwin {
    # Darwin doesn't have nh darwin rollback, use darwin-rebuild instead
    let result = (^darwin-rebuild switch --rollback-to $num | complete)
    if $result.exit_code == 0 {
      notify "Flake Generation" "Generation switch complete" "success"
    } else {
      notify "Flake Generation" $"Failed to switch generation: ($result.stderr)" "error"
    }
  } else {
    nh os rollback --to $num
    notify "Flake Generation" "Generation switch complete" "success"
  }
}

def delete-generation [num: int] {
  notify "Flake Generation" $"Deleting generation ($num)..." "pending"
  sudo nix-env --delete-generations $num -p /nix/var/nix/profiles/system
  notify "Flake Generation" "Generation deleted" "success"
}

def main [action: string = "list", num?: int] {
  match $action {
    "list" => list-generations
    "bootloader" => list-bootloader-entries
    "switch" => {
      list-generations
      print ""
      
      let gen_num = if ($num | is-empty) {
        let result = (prompt-number "Enter generation number to switch to")
        if ($result == null) {
          return
        }
        $result
      } else {
        $num
      }
      
      switch-generation $gen_num
    }
    "delete" => {
      list-generations
      print ""
      
      let gen_num = if ($num | is-empty) {
        let result = (prompt-number "Enter generation number to delete")
        if ($result == null) {
          return
        }
        $result
      } else {
        $num
      }
      
      delete-generation $gen_num
    }
    _ => {
      print-error $"Unknown action: ($action)"
      print "Actions: list, bootloader, switch [num], delete [num]"
      exit 1
    }
  }
  print-header "END"
}

