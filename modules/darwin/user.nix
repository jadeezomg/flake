{
  config,
  pkgs,
  hostData,
  hostKey,
  user,
  ...
}: let
  host = hostData.hosts.${hostKey} or {};
in {
  # Configure settings for existing macOS user account
  # The user must already exist in macOS (created via System Preferences)
  users.users.${user} = {
    name = user;
    home = host.homeDirectory or "/Users/${user}";
    shell = pkgs.nushell;
  };
}
