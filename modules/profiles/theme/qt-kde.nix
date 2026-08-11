# Qt/KDE palette payload (HM half) — pushed with ./gui.nix.
#
# Stylix already covers Qt widget apps: its `qt` target selects Kvantum as the
# QStyle and builds a Base16Kvantum theme. Two surfaces stay light without the
# code below.
#
#   1. Kirigami/QML apps (kdeconnect, most KDE apps) never touch QStyle. They
#      read KColorScheme, which reads the [Colors:*] groups of kdeglobals.
#      Stylix's `kde` target writes a kdeglobals that only *names* the scheme
#      (UiSettings.ColorScheme) and ships the matching .colors file. Plasma
#      copies the groups in, through plasma-apply-lookandfeel. That tool does
#      not exist in a niri session, so the groups never arrive.
#   2. Stylix sets `custom_palette=true` in qt6ct.conf but no
#      `color_scheme_path`, so qt6ct has no palette to load.
#
# Both files come from dotfilesLib.palette, so they follow lib/theme-palette.nix.
# ~/.config/kdeglobals is used on purpose instead of XDG_CONFIG_DIRS: Home
# Manager exports xdg.systemDirs.config through the shell profile only, and
# kdeconnectd is DBus-activated under systemd, which never sources it.
{
  dotfilesLib,
  lib,
  pkgs,
  ...
}:
let
  inherit (dotfilesLib) palette;

  # KConfig wants decimal "R,G,B" triples, and qt6ct wants "#rrggbb".
  hexDigit = {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
    a = 10;
    b = 11;
    c = 12;
    d = 13;
    e = 14;
    f = 15;
  };

  byteAt =
    digits: offset:
    16 * hexDigit.${builtins.substring offset 1 digits}
    + hexDigit.${builtins.substring (offset + 1) 1 digits};

  rgb =
    hex:
    let
      digits = lib.toLower (lib.removePrefix "#" hex);
    in
    lib.concatMapStringsSep "," (offset: toString (byteAt digits offset)) [
      0
      2
      4
    ];

  # ---- kdeglobals ----------------------------------------------------------

  # The foreground roles are the same in every group; only the two backgrounds
  # and the plain text color change per group.
  foregrounds = {
    ForegroundInactive = palette.ansi-bright-black;
    ForegroundActive = palette.accent-yellow;
    ForegroundLink = palette.accent-blue;
    ForegroundVisited = palette.ansi-magenta;
    ForegroundNegative = palette.ansi-red;
    ForegroundNeutral = palette.ansi-yellow;
    ForegroundPositive = palette.ansi-green;
  };

  decorations = {
    DecorationFocus = palette.accent-blue;
    DecorationHover = palette.accent-yellow;
  };

  colorGroup =
    {
      background,
      alternate,
      foreground,
    }:
    {
      BackgroundNormal = background;
      BackgroundAlternate = alternate;
      ForegroundNormal = foreground;
    }
    // foregrounds
    // decorations;

  colorGroups = {
    # Editors and item views sit on the darker background.
    "Colors:View" = colorGroup {
      background = palette.bg-secondary;
      alternate = palette.bg-primary;
      foreground = palette.text-primary;
    };
    "Colors:Window" = colorGroup {
      background = palette.bg-primary;
      alternate = palette.bg-secondary;
      foreground = palette.text-primary;
    };
    "Colors:Button" = colorGroup {
      background = palette.bg-tertiary;
      alternate = palette.bg-primary;
      foreground = palette.text-primary;
    };
    "Colors:Selection" = colorGroup {
      background = palette.accent-blue;
      alternate = palette.accent-blue;
      foreground = palette.text-secondary;
    };
    "Colors:Tooltip" = colorGroup {
      background = palette.bg-secondary;
      alternate = palette.bg-primary;
      foreground = palette.text-primary;
    };
    "Colors:Complementary" = colorGroup {
      background = palette.bg-secondary;
      alternate = palette.bg-primary;
      foreground = palette.text-primary;
    };
    "Colors:Header" = colorGroup {
      background = palette.bg-primary;
      alternate = palette.bg-secondary;
      foreground = palette.text-primary;
    };
  };

  # Window decorations. Stylix writes [WM] fonts into the kdeglobals it puts on
  # XDG_CONFIG_DIRS; KConfig merges per key, so these colors add to them.
  windowManager = {
    activeBackground = palette.bg-secondary;
    activeForeground = palette.text-primary;
    activeBlend = palette.accent-blue;
    inactiveBackground = palette.bg-primary;
    inactiveForeground = palette.ansi-bright-black;
    inactiveBlend = palette.bg-tertiary;
  };

  renderGroup =
    name: entries:
    lib.concatStringsSep "\n" (
      [ "[${name}]" ] ++ lib.mapAttrsToList (key: hex: "${key}=${rgb hex}") entries
    );

  kdeglobals = lib.concatStringsSep "\n\n" (
    [
      # ColorScheme must match the name Stylix gives its .colors file, so the
      # System Settings UI and these groups agree.
      ''
        [General]
        ColorScheme=BirdsofParadise''
    ]
    ++ lib.mapAttrsToList renderGroup colorGroups
    ++ [ (renderGroup "WM" windowManager) ]
  );

  # ---- qt5ct/qt6ct color scheme -------------------------------------------

  # QPalette roles, in the order qt6ct writes them: WindowText, Button, Light,
  # Midlight, Dark, Mid, Text, BrightText, ButtonText, Base, Window, Shadow,
  # Highlight, HighlightedText, Link, LinkVisited, AlternateBase, NoRole,
  # ToolTipBase, ToolTipText, PlaceholderText.
  qtRoles =
    {
      text,
      dim,
      highlight,
      highlightText,
    }:
    lib.concatStringsSep ", " [
      text # WindowText
      palette.bg-tertiary # Button
      palette.bg-secondary # Light
      palette.ansi-black # Midlight
      palette.bg-primary # Dark
      palette.bg-primary # Mid
      text # Text
      palette.text-secondary # BrightText
      text # ButtonText
      palette.bg-secondary # Base
      palette.bg-primary # Window
      "#000000" # Shadow
      highlight # Highlight
      highlightText # HighlightedText
      palette.accent-blue # Link
      palette.ansi-magenta # LinkVisited
      palette.bg-primary # AlternateBase
      palette.bg-tertiary # NoRole
      palette.bg-tertiary # ToolTipBase
      palette.text-primary # ToolTipText
      dim # PlaceholderText
    ];

  qtColorScheme = pkgs.writeText "birds-of-paradise.conf" ''
    [ColorScheme]
    active_colors=${
      qtRoles {
        text = palette.text-primary;
        dim = palette.text-tertiary;
        highlight = palette.accent-blue;
        highlightText = palette.text-secondary;
      }
    }
    inactive_colors=${
      qtRoles {
        text = palette.text-tertiary;
        dim = palette.ansi-bright-black;
        highlight = palette.bg-tertiary;
        highlightText = palette.text-primary;
      }
    }
    disabled_colors=${
      qtRoles {
        text = palette.ansi-bright-black;
        dim = palette.ansi-bright-black;
        highlight = palette.bg-tertiary;
        highlightText = palette.ansi-bright-black;
      }
    }
  '';

  qtctSettings = {
    Appearance.color_scheme_path = "${qtColorScheme}";
  };
in
{
  xdg.configFile."kdeglobals".text = kdeglobals + "\n";

  qt = {
    qt5ctSettings = qtctSettings;
    qt6ctSettings = qtctSettings;
  };
}
