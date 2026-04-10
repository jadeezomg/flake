# Additional normal user accounts from hostData (e.g. guest logins).
# Primary account remains modules/nixos/user.nix (`user` specialArg).
{
  hostData,
  hostKey,
  lib,
  pkgs,
  ...
}: let
  host = hostData.hosts.${hostKey} or {};
  extras = host.extraUsers or [];
  mkUser = u:
    lib.nameValuePair u.username {
      isNormalUser = true;
      description = u.description or u.fullName or u.username;
      extraGroups = u.extraGroups or [];
      shell = u.shell or pkgs.bashInteractive;
      packages = with pkgs; u.packages or [];
    };
in {
  users.users = lib.listToAttrs (map mkUser extras);
}
