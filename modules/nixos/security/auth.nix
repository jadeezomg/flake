{ pkgs, pkgs-unstable, ... }:

{
  # Authentication configuration
  # PAM configuration, etc.

  # Password managers
  environment.systemPackages = with pkgs; [
    pkgs-unstable.proton-pass
  ];
}

