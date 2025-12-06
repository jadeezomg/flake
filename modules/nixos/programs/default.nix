{ config, pkgs, ... }:

{
  # NixOS-specific programs configuration
  # Shared programs (like git) are in modules/shared/programs
  programs = {
    firefox.enable = true;
  };
}

