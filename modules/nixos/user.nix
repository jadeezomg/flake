{
  config,
  lib,
  pkgs,
  hostData,
  hostKey,
  user,
  ...
}: let
  host = hostData.hosts.${hostKey} or {};
  userConfig = host.user or {};
  localeConfig =
    host.locale or {
      defaultLocale = "en_US.UTF-8";
      timeZone = "Europe/Berlin";
      extraLocaleSettings = {
        LC_ADDRESS = "de_DE.UTF-8";
        LC_IDENTIFICATION = "de_DE.UTF-8";
        LC_MEASUREMENT = "de_DE.UTF-8";
        LC_MONETARY = "de_DE.UTF-8";
        LC_NAME = "de_DE.UTF-8";
        LC_NUMERIC = "de_DE.UTF-8";
        LC_PAPER = "de_DE.UTF-8";
        LC_TELEPHONE = "de_DE.UTF-8";
        LC_TIME = "de_DE.UTF-8";
      };
    };
in {
  users.mutableUsers = false;

  # mini sets `hashedPasswordFile` via its own bootstrap toggle in
  # `hosts/mini/default.nix`; opt it out here to avoid a double-decl.
  sops.secrets."users/jadee/password" = lib.mkIf (hostKey != "mini") {
    neededForUsers = true;
  };

  users.users.${user} = {
    isNormalUser = true;
    description = userConfig.description or "user account";
    extraGroups = userConfig.extraGroups or ["wheel"];
    shell = pkgs.nushell;
    packages = userConfig.packages or [];
    openssh.authorizedKeys.keys = userConfig.sshKeys or [];
    hashedPasswordFile = lib.mkIf (hostKey != "mini") config.sops.secrets."users/jadee/password".path;
  };

  time.timeZone = localeConfig.timeZone;
  services.timesyncd.enable = true;

  i18n.defaultLocale = localeConfig.defaultLocale;
  i18n.extraLocaleSettings = localeConfig.extraLocaleSettings;
}
