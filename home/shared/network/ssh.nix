{lib, ...}: let
  sshDestinations = (import ../../../data/network/ssh-destinations.nix).destinations;
  hostBlocks =
    lib.mapAttrs (_alias: {
      hostName,
      user,
      ...
    }: {
      HostName = hostName;
      User = user;
    })
    sshDestinations;
in {
  programs.ssh = {
    enable = true;
    settings =
      {
        "*" = {
          StrictHostKeyChecking = "accept-new";
        };
      }
      // hostBlocks;
  };
}
