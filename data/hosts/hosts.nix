let
  userData = import ../users/users.nix;

  # Shared user configuration for NixOS hosts
  # Individual hosts can override specific fields
  sharedNixOSUser = userData.users.jadee;

  # Darwin host can override the base user via users.caya if present
  darwinUser = userData.users.jadee;

  # Shared host configuration for NixOS hosts
  # Individual hosts can override specific fields
  sharedNixOSHost = {
    username = sharedNixOSUser.username;
    system = "x86_64-linux";
    homeDirectory = "/home/${sharedNixOSUser.username}";
    stateVersion = "25.11";
  };

  hosts = {
    framework =
      sharedNixOSHost
      // {
        hostname = "framework-nixos";
        description = "Jadee Framework NixOS Host";
        user = sharedNixOSUser;
        mainMonitor = {
          monitorID = "eDP-1";
          monitorResolution = "2880x1920";
          monitorRefreshRate = "120";
          monitorScalingFactor = "2.0";
        };
      };

    desktop =
      sharedNixOSHost
      // {
        hostname = "desktop-nixos";
        description = "Jadee Desktop NixOS Host";
        user = sharedNixOSUser;
      };

    caya = {
      hostname = "caya-darwin";
      description = "Jadee Caya Darwin Host";
      username = darwinUser.username;
      system = "aarch64-darwin";
      homeDirectory = darwinUser.homeDirectory or "/Users/${darwinUser.username}";
      stateVersion = darwinUser.stateVersion or "25.11";
      # Darwin user config is simpler - just shell configuration
      # The user must already exist in macOS
      user = darwinUser.user or {};
    };
  };
in {
  inherit hosts;
}
