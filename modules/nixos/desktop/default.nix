{pkgs, ...}: {
  imports = [
    ./gnome
    ./niri
  ];

  services = {
    displayManager.gdm = {
      enable = true;
      wayland = true;
    };
    gvfs.enable = true; # Mount, trash, etc
    tumbler.enable = true; # Thumbnail support for images
    xserver = {
      enable = true;
      # Configure keyboard layout (works for both Wayland and X11)
      xkb = {
        layout = "us";
        variant = "euro";
      };
    };
  };

  environment.systemPackages = with pkgs; [
    libnotify # Desktop notifications
    nautilus # File manager
  ];
}
