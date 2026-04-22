{...}: {
  # All theme content is gated inside each submodule on
  # `osConfig.dotfiles.profiles.essentials.enable`. Sandboxes and minimal-only
  # hosts get neither oh-my-posh nor the nushell color overlay.
  imports = [
    ./oh-my-posh.nix
    ./zsh.nix
    ./bash.nix
    ./fish.nix
    ./nushell.nix
  ];
}
