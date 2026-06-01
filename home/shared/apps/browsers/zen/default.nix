{
  inputs,
  lib,
  pkgs,
  config,
  osConfig,
  ...
}:
let
  extensions = import ./extensions.nix { inherit pkgs lib; };
  defaultProfile = import ./profiles/default { inherit pkgs extensions; };
  cayaProfile = import ./profiles/caya { inherit pkgs extensions lib; };
  defaultProfileData = if pkgs.stdenv.isLinux then defaultProfile else cayaProfile;
  activeProfileExtensions = defaultProfileData.profileExtensions;
  policies = import ./policies.nix {
    inherit pkgs lib extensions;
    profileExtensions = activeProfileExtensions;
  };

  themeColors = import ../../../assets/theme/theme.nix;
  stylixColors = config.lib.stylix.colors;

  stripSolidChromeBackgrounds = css: let
    lines = lib.splitString "
" css;
    isSolidChromeBg = line:
      lib.any (needle: lib.hasInfix needle line) [
        "background-color: #"
        "background: #"
        "--zen-main-browser-background:"
        "--zen-themed-toolbar-bg:"
        "--zen-main-browser-background-toolbar:"
        "--newtab-background-color:"
        "--lwt-sidebar-background-color:"
        "--toolbar-bgcolor:"
        "--arrowpanel-background:"
      ];
  in
    builtins.concatStringsSep "
" (lib.filter (line: !(isSolidChromeBg line)) lines);

  zenOpacity = config.stylix.opacity.applications;
  zenOpacityPercent = toString (lib.floor (zenOpacity * 100 + 0.5));

  stylixZenUserChrome = stripSolidChromeBackgrounds (
    import (inputs.stylix + "/modules/zen-browser/userChrome.nix") {
      colors = stylixColors;
    }
  );
  stylixZenUserContent = stripSolidChromeBackgrounds (
    import (inputs.stylix + "/modules/zen-browser/userContent.nix") {
      colors = stylixColors;
    }
  );

  zenChromeVars = ''
    :root {
      --zen-chrome-opacity: ${toString zenOpacity};
      --zen-chrome-opacity-percent: ${zenOpacityPercent}%;
      --zen-chrome-bg: ${themeColors.bg-primary};
      --zen-chrome-bg-secondary: ${themeColors.bg-secondary};
      --zen-chrome-tertiary: ${themeColors.bg-tertiary};
      --zen-background-opacity: ${toString zenOpacity} !important;
      --zen-opacity: ${toString zenOpacity} !important;
    }
  '';

  chromeOpacityLayer = lib.replaceStrings [ "90%" ] [ "${zenOpacityPercent}%" ] (
    builtins.readFile ./chrome/userChrome.css
  );

  contentOpacityLayer = lib.replaceStrings [ "90%" ] [ "${zenOpacityPercent}%" ] (
    builtins.readFile ./chrome/userContent.css
  );

  zenUserChrome = stylixZenUserChrome + "\n\n" + zenChromeVars + chromeOpacityLayer;
  zenUserContent = stylixZenUserContent + "\n\n" + zenChromeVars + contentOpacityLayer;

  zenManagedMods = [
    "e74cb40a-f3b8-445a-9826-1b1b6e41b846" # Custom uiFont
    "642854b5-88b4-4c40-b256-e035532109df" # Transparent Zen
    "a6335949-4465-4b71-926c-4a52d34bc9c0" # Better Find Bar
  ];

  zenThemesOverrides = ''
    /* nix: transparency overrides (after mod CSS; Zen regenerates this file on start) */
    .zen-browser-generic-background,
    #main-window .zen-browser-generic-background,
    zen-workspace .zen-browser-generic-background,
    .zen-browser-generic-background[style],
    #zen-browser-background[style] {
      background: transparent !important;
      background-color: transparent !important;
      background-image: none !important;
      --zen-main-browser-background: transparent !important;
    }
    #main-window,
    #browser,
    #zen-browser-background {
      background: transparent !important;
      background-color: transparent !important;
    }
    #navigator-toolbox,
    #titlebar,
    #TabsToolbar,
    #zen-appcontent-navbar-container,
    #zen-toolbar-background,
    .zen-toolbar-background,
    #sidebar-box,
    .sidebar-placesTree,
    #zen-workspaces-button,
    .content-shortcuts {
      background: var(--zen-chrome-surface-secondary) !important;
      background-color: var(--zen-chrome-surface-secondary) !important;
    }
    .urlbar-background {
      background-color: var(--zen-chrome-surface-tertiary) !important;
    }
    :root {
      --zen-main-browser-background: transparent !important;
      --zen-themed-toolbar-bg: var(--zen-chrome-surface-secondary) !important;
      --zen-themed-toolbar-bg-transparent: var(--zen-chrome-surface-secondary) !important;
    }
  '';

  zenThemesOverridesFile = pkgs.writeText "zen-nix-transparency-overrides.css" zenThemesOverrides;

  enableModsScript = pkgs.writeShellScript "zen-enable-managed-mods" (
    lib.concatMapStringsSep "\n" (uuid: ''
      if [ -f "$themesFile" ] && ${lib.getExe pkgs.jq} -e --arg u "${uuid}" 'has($u)' "$themesFile" >/dev/null 2>&1; then
        ${lib.getExe pkgs.jq} --arg u "${uuid}" '.[$u].enabled = true' "$themesFile" > "$themesFile.tmp" && mv "$themesFile.tmp" "$themesFile"
      fi
    '') zenManagedMods
  );

  regenerateThemesCssScript = pkgs.writeShellScript "zen-regenerate-themes-css" ''
    set -euo pipefail
    themesCss="$1"
    themesFile="$2"
    themesDir="$3"
    overridesFile="$4"

    tmpMods=$(mktemp)
    ${lib.getExe pkgs.jq} -r 'to_entries[] | select(.value.enabled == null or .value.enabled == true) | .key' "$themesFile" > "$tmpMods"

    {
      echo "/* Zen Mods - Generated by Nix (managed mods + transparency overrides). */"
      while read -r mod_uuid; do
        mod_css="$themesDir/$mod_uuid/chrome.css"
        if [ -f "$mod_css" ]; then
          ${lib.getExe pkgs.jq} -r ".\"$mod_uuid\" | \"/* Name: \(.name) */\\n/* Description: \(.description) */\\n/* Author: @\(.author) */\"" "$themesFile"
          cat "$mod_css"
          echo ""
        fi
      done < "$tmpMods"
      echo "/* End of Zen Mods */"
      echo ""
      cat "$overridesFile"
    } > "$themesCss"

    rm -f "$tmpMods"
  '';

  zenBetaBin = lib.getExe (
    config.programs.zen-browser.package or pkgs.zen-beta
  );

  zenBetaWrapper = pkgs.writeShellScriptBin "zen-beta" ''
    set -euo pipefail
    profileDir="${config.xdg.configHome}/zen/default"
    themesFile="$profileDir/zen-themes.json"
    themesCss="$profileDir/chrome/zen-themes.css"
    themesDir="$profileDir/chrome/zen-themes"

    if [ -f "$themesFile" ]; then
      themesFile="$themesFile" ${enableModsScript}
      ${regenerateThemesCssScript} "$themesCss" "$themesFile" "$themesDir" "${zenThemesOverridesFile}"
    fi

    exec ${zenBetaBin} "$@"
  '';
in
{
  imports = [
    inputs.zen-browser.homeModules.beta
  ];

  programs.zen-browser = lib.mkIf (osConfig.dotfiles.profiles.apps.browsers.enable or false) {
    enable = true;
    nativeMessagingHosts = lib.optionals pkgs.stdenv.isLinux [ pkgs.firefoxpwa ];
    darwinDefaultsId = lib.mkIf (!pkgs.stdenv.isLinux) "com.zen.browser";

    inherit policies;

    profiles.default = builtins.removeAttrs defaultProfileData [ "profileExtensions" ] // {
      id = 0;
      isDefault = true;
      settings = defaultProfileData.settings // {
        "mod.sameerasw.zen_bg_opacity" = zenOpacity;
        "mod.sameerasw.zen_bg_color_enabled" = false;
      };
      userChrome = zenUserChrome;
      userContent = zenUserContent;
      mods = zenManagedMods;
    };
  };

  home.packages = lib.mkIf (osConfig.dotfiles.profiles.apps.browsers.enable or false) [
    zenBetaWrapper
  ];

  home.activation.zenModsAndThemesFix = lib.hm.dag.entryAfter [ "zen-mods-default" ] ''
    profileDir="${config.xdg.configHome}/zen/default"
    themesFile="$profileDir/zen-themes.json"
    themesCss="$profileDir/chrome/zen-themes.css"
    themesDir="$profileDir/chrome/zen-themes"

    if [ -f "$themesFile" ]; then
      themesFile="$themesFile" ${enableModsScript}
      ${regenerateThemesCssScript} "$themesCss" "$themesFile" "$themesDir" "${zenThemesOverridesFile}"
    fi
  '';
}
