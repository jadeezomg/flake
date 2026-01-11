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
      gtk = {
        extraCss = ''
          /* Reduce GTK decoration font size */
          headerbar.titlebar,
          .titlebar,
          headerbar {
            font-size: 10pt;
          }

          headerbar.titlebar .title,
          .titlebar .title,
          headerbar .title {
            font-size: 10pt;
          }
        '';
      };
    };
  };
}
