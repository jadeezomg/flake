{
  inputs,
  lib,
  pkgs,
  ...
}: let
  extensions = import ./extensions.nix {inherit pkgs lib;};
  sharedSettings = import ./settings.nix;
  sharedSearch = import ./search.nix {inherit pkgs;};
  defaultProfile = import ./profiles/default {
    inherit
      pkgs
      extensions
      sharedSettings
      sharedSearch
      ;
  };
  cayaProfile = import ./profiles/caya {
    inherit
      pkgs
      extensions
      lib
      sharedSettings
      sharedSearch
      ;
  };
  defaultProfileData =
    if pkgs.stdenv.isLinux
    then defaultProfile
    else cayaProfile;
  activeProfileExtensions = defaultProfileData.profileExtensions;
  policies = import ./policies.nix {
    inherit pkgs lib extensions;
    profileExtensions = activeProfileExtensions;
  };

  zenManagedMods = [
    "e74cb40a-f3b8-445a-9826-1b1b6e41b846" # Custom uiFont
    "642854b5-88b4-4c40-b256-e035532109df" # Transparent Zen
    "a6335949-4465-4b71-926c-4a52d34bc9c0" # Better Find Bar
  ];
in {
  imports = [
    inputs.zen-browser.homeModules.beta
  ];

  programs.zen-browser = {
    enable = true;
    nativeMessagingHosts = lib.optionals pkgs.stdenv.isLinux [pkgs.firefoxpwa];
    darwinDefaultsId = lib.mkIf (!pkgs.stdenv.isLinux) "com.zen.browser";

    inherit policies;

    profiles.default =
      builtins.removeAttrs defaultProfileData ["profileExtensions"]
      // {
        id = 0;
        isDefault = true;
        mods = zenManagedMods;
      };
  };
}
