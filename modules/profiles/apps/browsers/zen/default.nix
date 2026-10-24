{
  config,
  inputs,
  lib,
  pkgs,
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
  defaultProfileData = if pkgs.stdenv.hostPlatform.isLinux then defaultProfile else cayaProfile;
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

  # Square UI (github.com/Louis047/Square-UI, MIT) makes tabs, buttons, menus,
  # panels, and the URL bar square. It is a Sine mod. The Zen mod store is
  # archived, and Sine needs a bootloader inside the read-only Zen install, so
  # its stylesheet loads as userChrome, after the Stylix colors. settings.nix
  # turns on only its browser section (mod.squareui.browser.enabled).
  squareUi = builtins.fetchTree {
    type = "github";
    owner = "Louis047";
    repo = "Square-UI";
    rev = "96da150de537db31dc06c6becbe701cd5c5a4972";
    narHash = "sha256-nrg2BwkAgqjl765aeg5d1M3kuYZgxqRiWoYEyl4oNBs=";
  };
  # The mod gates each section with the old (-moz-bool-pref: "x") query. Zen
  # mods now use -moz-pref("x"), so the stylesheet is rewritten to that form.
  squareUiChrome = builtins.replaceStrings [ "(-moz-bool-pref: " ] [ "-moz-pref(" ] (
    builtins.readFile "${squareUi}/userChrome.css"
  );

  # Keep one translucent layer, so Zen shows the Stylix opacity like kitty.
  # - Stylix sets the sidebar and toolbar layer (#zen-toolbar-background) to
  #   an opaque base00. Zen's own default is the translucent main background.
  # - Zen paints #zen-main-app-wrapper, behind everything, with
  #   --zen-themed-toolbar-bg-transparent, which Stylix sets to base01 at the
  #   same opacity. Two 90% layers measured as 96% on screen (2026-10-24).
  zenOpacityChrome = ''
    #zen-toolbar-background {
      --zen-main-browser-background-toolbar: var(--zen-main-browser-background) !important;
    }
    #zen-main-app-wrapper {
      background: transparent !important;
    }
  '';

  vicinaeNativeMessagingHost =
    pkgs.writeTextDir "lib/mozilla/native-messaging-hosts/com.vicinae.vicinae.json"
      (
        builtins.toJSON {
          name = "com.vicinae.vicinae";
          description = "Vicinae Native Messaging Host";
          # Follow programs.vicinae.package. A literal pkgs.vicinae here pins the
          # nixpkgs build, which has no darwin cache (see apps/vicinae.nix).
          path = "${config.programs.vicinae.package}/libexec/vicinae/vicinae-browser-link";
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
    nativeMessagingHosts = [ vicinaeNativeMessagingHost ];
    # `darwinDefaultsId` is deliberately left at the upstream default,
    # `app.zen-browser.zen` — Zen's real macOS bundle identifier, and the plist
    # domain it reads policies from. Overriding it writes ExtensionSettings to a
    # domain nothing reads, so force_installed extensions never appear.

    inherit policies;

    profiles.default = builtins.removeAttrs defaultProfileData [ "profileExtensions" ] // {
      id = 0;
      isDefault = true;
      mods = zenManagedMods;
      userChrome = lib.mkAfter (zenOpacityChrome + squareUiChrome);
    };
  };
}
