{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    alejandra # Nix formatter
    cachix # Cachix for Nix
    nixd # Nix language server
    nixfmt-rfc-style # Official formatter for Nix
    nixos-icons # NixOS icons
  ];
}
