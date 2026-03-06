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
  # Stylix-generated Zen CSS (same as stylix.targets.zen-browser) with our opacity appended
  stylixZenUserChrome = import (inputs.stylix + "/modules/zen-browser/userChrome.nix") {
    colors = config.lib.stylix.colors;
  };
  stylixZenUserContent = import (inputs.stylix + "/modules/zen-browser/userContent.nix") {
    colors = config.lib.stylix.colors;
  };
  extraUserChrome = builtins.readFile ./chrome/userChrome.css;
  extraUserContent = builtins.readFile ./chrome/userContent.css;
in {
  imports = [
    inputs.zen-browser.homeModules.beta
  ];

  programs.zen-browser = {
    enable = true;
    suppressXdgMigrationWarning = true;
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
        settings =
          defaultProfileData.settings
          // {"toolkit.legacyUserProfileCustomizations.stylesheets" = true;};
        userChrome = stylixZenUserChrome + "\n\n" + extraUserChrome;
        userContent = stylixZenUserContent + "\n\n" + extraUserContent;
      };
  };
}
# Check if Zen is running:
#    pgrep -f 'Zen.app' && echo "Zen is running" || echo "Zen is not running"
# Close Zen:
#    pkill -f 'Zen.app'

