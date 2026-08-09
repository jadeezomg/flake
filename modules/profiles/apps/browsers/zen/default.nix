{
  inputs,
  lib,
  pkgs,
  pkgs-stable,
  ...
}:
let
  extensions = import ./extensions.nix { inherit pkgs lib; };
  sharedSettings = import ./settings.nix;
  sharedSearch = import ./search.nix { inherit pkgs; };
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
  defaultProfileData = if pkgs.stdenv.isLinux then defaultProfile else cayaProfile;
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

  vicinaePkg =
    if pkgs.stdenv.isLinux then
      pkgs.vicinae
    else
      inputs.vicinae.packages.${pkgs.stdenv.hostPlatform.system}.default;
  vicinaeNativeMessagingHost =
    pkgs.writeTextDir "lib/mozilla/native-messaging-hosts/com.vicinae.vicinae.json"
      (
        builtins.toJSON {
          name = "com.vicinae.vicinae";
          description = "Vicinae Native Messaging Host";
          path = "${vicinaePkg}/libexec/vicinae/vicinae-browser-link";
          type = "stdio";
          allowed_extensions = [ "firefox@vicinae.com" ];
        }
      );
in
{
  imports = [
    inputs.zen-browser.homeModules.twilight
  ];

  programs.zen-browser = {
    enable = true;
    nativeMessagingHosts = (lib.optionals pkgs.stdenv.isLinux [ pkgs-stable.firefoxpwa ]) ++ [
      vicinaeNativeMessagingHost
    ];
    # `darwinDefaultsId` is deliberately left at the upstream default,
    # `app.zen-browser.zen` — Zen's real macOS bundle identifier, and the plist
    # domain it reads policies from. Overriding it writes ExtensionSettings to a
    # domain nothing reads, so force_installed extensions never appear.

    inherit policies;

    profiles.default = builtins.removeAttrs defaultProfileData [ "profileExtensions" ] // {
      id = 0;
      isDefault = true;
      mods = zenManagedMods;
    };
  };
}
