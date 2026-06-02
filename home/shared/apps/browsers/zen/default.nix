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

  zenOpacity = config.stylix.opacity.applications;
  zenOpacityPercent = toString (lib.floor (zenOpacity * 100 + 0.5));

  stylixZenUserChrome = import (inputs.stylix + "/modules/zen-browser/userChrome.nix") {
    colors = stylixColors;
  };
  stylixZenUserContent = import (inputs.stylix + "/modules/zen-browser/userContent.nix") {
    colors = stylixColors;
  };

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

  # Stylix first, then opacity layer (!important wins over Stylix solid #RRGGBB in the same file).
  zenUserChrome = stylixZenUserChrome + "\n\n" + zenChromeVars + chromeOpacityLayer;
  zenUserContent = stylixZenUserContent + "\n\n" + zenChromeVars + contentOpacityLayer;

  zenManagedMods = [
    "e74cb40a-f3b8-445a-9826-1b1b6e41b846" # Custom uiFont
    "642854b5-88b4-4c40-b256-e035532109df" # Transparent Zen
    "a6335949-4465-4b71-926c-4a52d34bc9c0" # Better Find Bar
  ];

  # zen-themes.css loads after userChrome.css; keep this minimal (mod bg color is off in settings).
  zenThemesTail = pkgs.writeText "zen-nix-transparency-tail.css" ''
    .zen-browser-generic-background {
      --zen-main-browser-background: transparent !important;
    }
  '';

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
    tailFile="$4"

    tmpMods=$(mktemp)
    ${lib.getExe pkgs.jq} -r 'to_entries[] | select(.value.enabled == null or .value.enabled == true) | .key' "$themesFile" > "$tmpMods"

    {
      echo "/* Zen Mods - managed by Home Manager */"
      while read -r mod_uuid; do
        mod_css="$themesDir/$mod_uuid/chrome.css"
        if [ -f "$mod_css" ]; then
          ${lib.getExe pkgs.jq} -r ".\"$mod_uuid\" | \"/* Name: \(.name) */\\n/* Description: \(.description) */\\n/* Author: @\(.author) */\"" "$themesFile"
          cat "$mod_css"
          echo ""
        fi
      done < "$tmpMods"
      cat "$tailFile"
    } > "$themesCss"

    rm -f "$tmpMods"
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
      };
      userChrome = zenUserChrome;
      userContent = zenUserContent;
      mods = zenManagedMods;
    };
  };

  home.activation.zenThemesCss = lib.hm.dag.entryAfter [ "zen-mods-default" ] ''
    profileDir="${config.xdg.configHome}/zen/default"
    themesFile="$profileDir/zen-themes.json"
    themesCss="$profileDir/chrome/zen-themes.css"
    themesDir="$profileDir/chrome/zen-themes"

    if [ -f "$themesFile" ]; then
      themesFile="$themesFile" ${enableModsScript}
      ${regenerateThemesCssScript} "$themesCss" "$themesFile" "$themesDir" "${zenThemesTail}"
    fi
  '';
}
