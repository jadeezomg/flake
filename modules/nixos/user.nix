{
  config,
  pkgs,
  hostData,
  hostKey,
  user,
  ...
}: let
  host = hostData.hosts.${hostKey} or {};
  userConfig = host.user or {};
in {
  # Define user account. Don't forget to set a password with 'passwd'.
  users.users.${user} = {
    isNormalUser = true;
    description = userConfig.description or "user account";
    extraGroups = userConfig.extraGroups or ["wheel"];
    shell = pkgs.nushell;
    packages = with pkgs; userConfig.packages or [];
  };
}
