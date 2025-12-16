{...}: {
  imports = [
    # Note: aliases.nix, config.nix, env.nix, paths.nix, and functions.nix
    # are data files, not Home Manager modules, so they're imported directly
    # in shell-specific files rather than via imports
    ./oh-my-posh.nix
  ];
}
