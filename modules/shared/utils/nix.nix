{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    cachix # Cachix for Nix
    nixos-icons # NixOS icons
    nh # Nix Helper
  ];
}
