{
  inputs,
  lib,
  pkgs,
  config,
  ...
}: let
  extensions = import ./extensions.nix {inherit pkgs lib;};
  defaultProfile = import ./profiles/default {inherit pkgs extensions;};
  cayaProfile = import ./profiles/caya {inherit pkgs extensions lib;};
  defaultProfileData =
    if pkgs.stdenv.isLinux
    then defaultProfile
    else cayaProfile;
  activeProfileExtensions = defaultProfileData.profileExtensions;
  policies = import ./policies.nix {
    inherit pkgs lib extensions;
    profileExtensions = activeProfileExtensions;
  };
  # Stylix colors with alpha on background hex keys (base00, base01, base02) so Zen theme is semi-transparent
  zenStylixAlpha = "CC"; # 80% opacity (255 * 0.8 = 204 = 0xCC)
  stylixColorsWithAlpha =
    lib.mapAttrs (
      name: val:
        if (name == "base00-hex" || name == "base01-hex" || name == "base02-hex")
        then val + zenStylixAlpha
        else val
    )
    config.lib.stylix.colors;
  stylixZenUserChrome = import (inputs.stylix + "/modules/zen-browser/userChrome.nix") {
    colors = stylixColorsWithAlpha;
  };
  stylixZenUserContent = import (inputs.stylix + "/modules/zen-browser/userContent.nix") {
    colors = stylixColorsWithAlpha;
  };
  extraUserChrome = builtins.readFile ./chrome/userChrome.css;
  extraUserContent = builtins.readFile ./chrome/userContent.css;
in {
  imports = [
    inputs.zen-browser.homeModules.beta
  ];

  programs.zen-browser = {
    enable = true;
    nativeMessagingHosts = lib.optionals pkgs.stdenv.isLinux [pkgs.firefoxpwa];
    # Required for macOS - see https://github.com/0xc000022070/zen-browser-flake#preferences
    # Verify the bundle identifier matches your Zen installation if policies don't work on macOS
    darwinDefaultsId = lib.mkIf (!pkgs.stdenv.isLinux) "com.zen.browser";

    inherit policies;

    profiles.default =
      builtins.removeAttrs defaultProfileData ["profileExtensions"]
      // {
        id = 0;
        isDefault = true;
        settings = defaultProfileData.settings;
        userChrome = stylixZenUserChrome;
        userContent = stylixZenUserContent;

        mods = [
          "e74cb40a-f3b8-445a-9826-1b1b6e41b846" # Custom uiFont
          "642854b5-88b4-4c40-b256-e035532109df" # Transparent Zen
          "a6335949-4465-4b71-926c-4a52d34bc9c0" # Better Find Bar
        ];
      };
  };
}
# Check if Zen is running:
#    pgrep -f 'Zen.app' && echo "Zen is running" || echo "Zen is not running"
# Close Zen:
#    pkill -f 'Zen.app'

