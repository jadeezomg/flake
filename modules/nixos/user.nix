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
  passwordSecretKey =
    {
      desktop = "users/jadee/password_desktop";
      framework = "users/jadee/password_framework";
      mini = "users/jadee/password_mini";
    }
    .${
      hostKey
    };
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

  # Per-host password hash. mini's bootstrap toggle is `miniBootstrap` in
  # `hosts/mini/host.nix` (see `hosts/mini/default.nix`).
  # gates its own declaration, so we opt it out here to avoid a double-decl.
  sops.secrets.${passwordSecretKey} = lib.mkIf (hostKey != "mini") {
    neededForUsers = true;
  };

  users.users.${user} = {
    isNormalUser = true;
    description = userConfig.description or "user account";
    extraGroups = userConfig.extraGroups or ["wheel"];
    shell = pkgs.nushell;
    packages = userConfig.packages or [];
    openssh.authorizedKeys.keys = userConfig.sshKeys or [];
    hashedPasswordFile = lib.mkIf (hostKey != "mini") config.sops.secrets.${passwordSecretKey}.path;
  };

  time.timeZone = localeConfig.timeZone;
  services.timesyncd.enable = true;

  i18n.defaultLocale = localeConfig.defaultLocale;
  i18n.extraLocaleSettings = localeConfig.extraLocaleSettings;
}
