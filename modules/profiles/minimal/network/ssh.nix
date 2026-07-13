{
  dotfilesLib,
  lib,
  ...
}:
let
  sshDestinations = dotfilesLib.sshDestinations;
  hostBlocks = lib.mapAttrs (
    _alias:
    {
      hostName,
      user,
      ...
    }:
    {
      HostName = hostName;
      User = user;
    }
  ) sshDestinations;
in
{
  programs.ssh = {
    enable = true;
    # HM defaults moved to explicit settings."*" (see home-manager modules/programs/ssh.nix).
    enableDefaultConfig = false;
    settings = {
      "*" = {
        ForwardAgent = false;
        AddKeysToAgent = "no";
        Compression = false;
        ServerAliveInterval = 0;
        ServerAliveCountMax = 3;
        HashKnownHosts = false;
        UserKnownHostsFile = "~/.ssh/known_hosts";
        ControlMaster = "no";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "no";
        StrictHostKeyChecking = "accept-new";
      };
    }
    // hostBlocks;
  };
}
