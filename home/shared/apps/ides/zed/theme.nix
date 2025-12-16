{lib, ...}: {
  programs.zed-editor = {
    userSettings = {
      # Let Stylix override the theme when `stylix.targets.zed-editor` (or similar) is enabled.
      theme = lib.mkDefault "SunsetForest";
      icon_theme = "Catppuccin Latte";
    };
  };
}
