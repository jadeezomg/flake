{
  config,
  pkgs,
  hostData,
  hostKey,
  user,
  ...
}:
let
  host = hostData.hosts.${hostKey} or { };
  userConfig = host.user or { };
  passwordSecretKey =
    {
      desktop = "users/jadee/password_desktop";
      framework = "users/jadee/password_framework";
      mini = "users/jadee/password_mini";
    }
    .${hostKey};
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
in
{
  users.mutableUsers = false;

  # Per-host password hash via sops (decrypted early; requires the host age
  # key at /var/lib/private/sops/age/keys.txt — on a FRESH install that key
  # doesn't exist yet, so a new host needs a temporary bootstrap exception
  # (see docs/hosts/mini.md § Secrets / § Rebuilding from scratch for the pattern).
  sops.secrets.${passwordSecretKey} = {
    neededForUsers = true;
  };

  users.users.${user} = {
    isNormalUser = true;
    description = userConfig.description or "user account";
    extraGroups = userConfig.extraGroups or [ "wheel" ];
    shell = pkgs.nushell;
    packages = userConfig.packages or [ ];
    openssh.authorizedKeys.keys = userConfig.sshKeys or [ ];
    hashedPasswordFile = config.sops.secrets.${passwordSecretKey}.path;
  };

  time.timeZone = localeConfig.timeZone;
  services.timesyncd.enable = true;

  i18n.defaultLocale = localeConfig.defaultLocale;
  i18n.extraLocaleSettings = localeConfig.extraLocaleSettings;
}
