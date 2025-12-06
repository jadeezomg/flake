{ pkgs, inputs, config, lib, ... }:

let
  # Determine system architecture
  # Use stdenv.hostPlatform.system instead of deprecated pkgs.system
  system = pkgs.stdenv.hostPlatform.system or config.nixpkgs.system or "x86_64-linux";
in
{
  environment.systemPackages = with pkgs; [
    nixd # Nix language server
  ] ++ lib.optionals (inputs.nil.packages ? ${system}) [
    inputs.nil.packages.${system}.default # Nix language server (nil)
  ];
}

