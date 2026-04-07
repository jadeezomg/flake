# Setup age key for SOPS on Darwin (Caya)
# Usage: nu setup-age-darwin.nu
# Run from flake root. Uses the flake dev shell for age (no need for system switch first).

use common.nu *
use theme.nu *

def main [] {
  let flake_path = (get-flake-path)
  let key_dir = $"($env.HOME)/.config/sops/age"
  let key_file = $"($key_dir)/keys.txt"

  print-pending "Setting up age key for nix-sops on Darwin"
  print ""

  # Create directory
  if not ($key_dir | path exists) {
    mkdir $key_dir
    print-success $"Created ($key_dir)"
  } else {
    print $"Key directory exists: ($key_dir)"
  }

  # Generate key if missing (use flake dev shell so age is available before first switch)
  if not ($key_file | path exists) {
    print-pending "Generating new age key..."
    ^nix develop $flake_path --command age-keygen -o $key_file
    print-success "Age key generated"
  } else {
    print $"Age key already exists: ($key_file)"
  }

  # Show public key
  let pubkey = (^nix develop $flake_path --command age-keygen -y $key_file | str trim)
  print ""
  print (ansi $theme_colors.success_bold) "Your age public key (add this to .sops.yaml as the Caya key):"
  print (ansi reset) $pubkey
  print ""
  print (ansi $theme_colors.info_bold) "Next steps:"
  print (ansi reset) "1. In .sops.yaml, replace the Caya placeholder key with the key above."
  print "2. Rekey existing secrets (from flake root; uses dev shell if sops not in PATH):"
  print (ansi $theme_colors.pending_bold) "   nix develop --command sops updatekeys secrets/secrets.yaml"
  print (ansi reset) "3. Rebuild and switch:  switch.nu caya"
  print ""
  print-success "Age key is at ($key_file); sops-nix will use it from ~/.config/sops/age/keys.txt"
}
