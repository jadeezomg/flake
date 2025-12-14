{ pkgs, pkgs-unstable, ... }:

{
  # Authentication configuration
  # PAM configuration, etc.

  # Password managers
  environment.systemPackages = with pkgs-unstable; [
    proton-pass
  ];
}
