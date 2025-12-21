{
  config,
  pkgs,
  ...
}: {
  # Enable Noctalia shell for Niri
  # This provides a desktop shell experience on top of Niri compositor
  programs.noctalia-shell = {
    enable = true;
  };

  # Configure Niri to start Noctalia shell automatically
  # This creates/updates ~/.config/niri/config.kdl
  xdg.configFile."niri/config.kdl".text = ''
    # Niri configuration with Noctalia shell
    # This file is managed by home-manager

    # Start Noctalia shell at startup
    spawn-at-startup {
      command = "qs"
      args = ["-c" "noctalia-shell"]
    }

    # You can add additional Niri configuration here
    # See: https://github.com/YaLTeR/niri/wiki/Configuration
  '';
}
