{
  config,
  pkgs,
  host,
  hostKey,
  user,
  ...
}:
let
  userConfig = host.user or { };
  # One sops entry per host, named after the user and the host key.
  # See secrets/SCHEMA.md.
  passwordSecretKey = "users/${user}/password_${hostKey}";
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

  # Same locale on every Linux host: English UI, German formats.
  time.timeZone = "Europe/Berlin";
  services.timesyncd.enable = true;

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
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
}
