{
  config,
  pkgs,
  ...
}: {
  # Enable Noctalia shell for Niri
  # This provides a desktop shell experience on top of Niri compositor
  # See: https://docs.noctalia.dev/getting-started/compositor-settings/niri/
  programs.noctalia-shell = {
    enable = true;
  };

  # Install quickshell (qs CLI tool) which is required for noctalia-shell IPC commands
  # The qs command is used for controlling noctalia-shell features like:
  # - qs -c noctalia-shell ipc call launcher toggle
  # - qs -c noctalia-shell ipc call controlCenter toggle
  # etc.
  home.packages = with pkgs; [
    quickshell
  ];

  # Manage Niri configuration files
  # These files are managed declaratively through home-manager
  xdg.configFile."niri/config.kdl".source = ./niri/config.kdl;
  xdg.configFile."niri/noctalia.kdl".source = ./niri/noctalia.kdl;
}
