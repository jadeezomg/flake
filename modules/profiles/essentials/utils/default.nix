{ pkgs, ... }: {
  imports = [
    ./core.nix
    ./text.nix
    ./navi
    ./television
    ./yazi
  ];
  home.packages = with pkgs; [
    nix-du # Disk usage analyzer for nix store
    nix-output-monitor # Better nix build output
    nix-prefetch-github # Prefetch sources from github. Useful for computing commit hashes.
    nix-search # Search nix packages
    nix-tree # Explore nix store
    nix-update # Update nix package versions
  ];
}
