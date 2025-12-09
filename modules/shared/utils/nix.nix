{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    nixd # Nix language server
    nixfmt-rfc-style # Official formatter for Nix
  ];
}
