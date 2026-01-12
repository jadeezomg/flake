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
          /* Reduce overall text size across GTK applications */
          * {
            font-size: 10pt;
          }

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

          /* Specific element text size adjustments */
          label {
            font-size: 10pt;
          }

          button {
            font-size: 10pt;
          }

          entry {
            font-size: 10pt;
          }

          textview text {
            font-size: 10pt;
          }

          menu {
            font-size: 10pt;
          }

          menuitem {
            font-size: 10pt;
          }

          toolbar {
            font-size: 10pt;
          }

          notebook tab {
            font-size: 10pt;
          }

          treeview {
            font-size: 10pt;
          }

          list {
            font-size: 10pt;
          }
        '';
      };
    };
  };
}
