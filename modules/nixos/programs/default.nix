{
  config,
  pkgs,
  ...
}: {
  # NixOS-specific programs configuration
  # Shared programs (like git) are in modules/shared/programs
  programs = {
    firefox.enable = true;
    steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports used by Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports used by Source Dedicated Server
      # Allow Steam to run with additional paths for external drives
      extraEnv = {
        STEAM_EXTRA_COMPAT_TOOLS_PATHS = "/run/media/jadee/The Solid State/Games/SteamLibrary/steamapps/compatibilitytools.d";
      };
      # Mount additional directories in Steam's FHS environment
      extraMounts = {
        "/run/media/jadee" = "/run/media/jadee";
      };
    };
  };
}
