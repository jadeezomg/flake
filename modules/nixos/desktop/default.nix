{pkgs, ...}: {
  imports = [
    ./gnome
    ./niri
  ];

  # DankGreeter — replaces GDM for reliable multi-monitor Wayland login
  programs.dank-material-shell.greeter = {
    enable = true;
    compositor.name = "niri";
    configHome = "/home/jadee";
    configFiles = ["/home/jadee/.config/DankMaterialShell/settings.json"];
  };

  services = {
    gvfs.enable = true; # Mount, trash, etc
    tumbler.enable = true; # Thumbnail support for images
    xserver = {
      enable = true;
      # Configure keyboard layout (works for both Wayland and X11)
      xkb = {
        layout = "us";
        variant = "intl";
      };
    };
  };

  # Niri is the primary compositor; include GNOME in XDG_CURRENT_DESKTOP so
  # gnome-control-center and other GNOME tools detect a compatible session.
  environment.sessionVariables.XDG_CURRENT_DESKTOP = "niri:GNOME";

  environment.systemPackages = with pkgs; [
    libnotify # Desktop notifications
    nautilus # File manager
  ];
}
