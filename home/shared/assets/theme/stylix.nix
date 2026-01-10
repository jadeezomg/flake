{pkgs, ...}: {
  stylix = {
    autoEnable = true;
    overlays.enable = false;

    targets = {
      wezterm.enable = false;
      vscode.enable = false;
      firefox.enable = false;
      zen-browser.profileNames = ["default"];
      # gnome.enable = false;
      # qt.enable = false;
    };
  };
}
