{
  inputs,
  lib,
  pkgs,
  ...
}: let
  extensions = import ./extensions.nix {inherit pkgs lib;};
  defaultProfile = import ./profiles/default.nix {inherit pkgs extensions;};
  cayaProfile = import ./profiles/caya.nix {inherit pkgs extensions;};
  # Use extensions from whichever profile is marked as default
  activeProfileExtensions =
    if defaultProfile.isDefault
    then defaultProfile.profileExtensions
    else cayaProfile.profileExtensions;
  policies = import ./policies.nix {
    inherit pkgs lib extensions;
    profileExtensions = activeProfileExtensions;
  };
in {
  imports = [
    inputs.zen-browser.homeModules.twilight
  ];

  programs.zen-browser = {
    enable = true;
    nativeMessagingHosts = lib.optionals pkgs.stdenv.isLinux [pkgs.firefoxpwa];

    inherit policies;

    profiles = {
      default = removeAttrs defaultProfile ["profileExtensions"];
      caya = removeAttrs cayaProfile ["profileExtensions"];
    };
  };
}
