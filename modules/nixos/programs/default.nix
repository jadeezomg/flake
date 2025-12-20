{
  config,
  pkgs,
  ...
}: {
  # NixOS-specific programs configuration
  # Shared programs (like git) are in modules/shared/programs
  programs = {
    firefox.enable = true;
    gamemode.enable = true;
    steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports used by Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports used by Source Dedicated Server
      gamescopeSession.enable = true;
    };
  };
  environment.systemPackages = with pkgs; [
    mangohud
    protonup-ng
  ];

  environment.sessionVariables = {
    STEAM_EXTRA_COMPAT_TOOLS_PATH = "/home/jadee/.steam/root/compatibilitytools.d";
  };
}
