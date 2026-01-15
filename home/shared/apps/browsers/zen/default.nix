{
  inputs,
  lib,
  pkgs,
  ...
}: let
  extensions = import ./extensions.nix {inherit pkgs lib;};
  defaultProfile = import ./profiles/default.nix {inherit pkgs extensions;};
  cayaProfile = import ./profiles/caya.nix {inherit pkgs extensions;};
  defaultProfileData =
    if pkgs.stdenv.isLinux
    then defaultProfile
    else cayaProfile;
  activeProfileExtensions = defaultProfileData.profileExtensions;
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
    # Required for macOS - see https://github.com/0xc000022070/zen-browser-flake#preferences
    # Verify the bundle identifier matches your Zen installation if policies don't work on macOS
    darwinDefaultsId = lib.mkIf (!pkgs.stdenv.isLinux) "com.zen.browser";

    inherit policies;

    profiles.default = {
      inherit defaultProfileData;
      id = 0;
      isDefault = true;
    };
  };
}
# Or as separate steps:
# Check if Zen is running:
#    pgrep -f 'Zen.app' && echo "Zen is running" || echo "Zen is not running"
#    pgrep -f 'Zen.app' && echo "Zen is running" || echo "Zen is not running"
# Close Zen:
#    pkill -f 'Zen.app'
# Verify it's closed (wait 2 seconds):
#    sleep 2 && pgrep -f 'Zen.app' && echo "Still running!" || echo "Zen is closed ✓"
# Then rebuild:
#    nh darwin switch --hostname caya

