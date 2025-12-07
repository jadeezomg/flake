{ pkgs, ... }:
{
  # Provide encryption tooling for Home Manager users on all platforms.
  home.packages = with pkgs; [
    age
    sops
  ];
}
