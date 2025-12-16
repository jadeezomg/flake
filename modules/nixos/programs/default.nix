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
    };
  };
}
