{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    cachix # Cachix for Nix
    nixd # Nix language server
    nixfmt-rfc-style # Official formatter for Nix
    nixos-icons # NixOS icons
  ];
}
