rec {
  # Shared user configuration for NixOS hosts
  # Individual hosts can override specific fields
  sharedNixOSUser = {
    username = "jadee";
    fullName = "Jonas Hippauf";
    email = "me@jadee.fyi";
    description = "jadee";
    extraGroups = [
      "input"
      "networkmanager"
      "uinput"
      "video"
      "wheel"
      # "docker" # Uncomment if docker service is enabled
    ];
    packages = [
      # Add host-specific packages here if needed
    ];
  };

  # Shared host configuration for NixOS hosts
  # Individual hosts can override specific fields
  sharedNixOSHost = rec {
    username = sharedNixOSUser.username;
    system = "x86_64-linux";
    homeDirectory = "/home/${username}";
    stateVersion = "25.11";
  };

  hosts = {
    framework = sharedNixOSHost // rec {
      hostname = "jadee-framework-nixos";
      description = "Jadee Framework NixOS Host";
      user = sharedNixOSUser // {
        # Host-specific overrides can go here
        # packages = sharedNixOSUser.packages ++ [ "somePackage" ];
      };
      mainMonitor = {
        monitorID = "eDP-1";
        monitorResolution = "2880x1920";
        monitorRefreshRate = "120";
        monitorScalingFactor = "2.0";
      };
    };

    desktop = sharedNixOSHost // rec {
      hostname = "jadee-desktop-nixos";
      description = "Jadee Desktop NixOS Host";
      user = sharedNixOSUser // {
        # Host-specific overrides can go here
        # packages = sharedNixOSUser.packages ++ [ "somePackage" ];
      };
    };

    caya = rec {
      hostname = "jadee-caya-darwin";
      description = "Jadee Caya Darwin Host";
      username = "jadee"; # Change this to your actual macOS Apple account username
      system = "aarch64-darwin";
      homeDirectory = "/Users/${username}";
      stateVersion = "25.11";
      # Darwin user config is simpler - just shell configuration
      # The user must already exist in macOS
      user = {
        # Darwin only needs shell config, user must exist in macOS
      };
    };
  };
}
