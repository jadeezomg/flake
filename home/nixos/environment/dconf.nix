{...}: {
  dconf.enable = true;
  dconf.settings = {
    "org/gnome/mutter".experimental-features = [
      "scale-monitor-framebuffer"
    ];
    # Reduce GTK decoration font size
    # Note: titlebar-font is deprecated but may still work on some systems
    "org/gnome/desktop/wm/preferences" = {
      titlebar-font = "Iosevka Nerd Font 10";
    };
    # Set Kanagawa Dragon GTK theme
    "org/gnome/desktop/interface" = {
      gtk-theme = "Kanagawa-Dragon";
    };
  };
}
