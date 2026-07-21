{
  config,
  host,
  lib,
  pkgs,
  user,
  ...
}:
let
  cfg = config.dotfiles.profiles.desktop;
  useDmsGreeter = cfg.loginManager == "dms-greeter";
  home = host.homeDirectory;
  flakeRoot = "${home}/.dotfiles/flake";
  dmsConfigDir = "${flakeRoot}/modules/profiles/desktop/dms/config";
in
{
  config = lib.mkIf (cfg.enable && useDmsGreeter) {
    # Greeter runs as a separate user; grant read access to the user's DMS config.
    # Equivalent of `dms greeter sync`, which is unavailable on NixOS.
    users.users.${user}.extraGroups = [ "greeter" ];

    systemd.services.dms-greeter-acl = {
      description = "Set ACL permissions for DMS greeter config sync";
      before = [ "greetd.service" ];
      wantedBy = [ "graphical.target" ];
      serviceConfig.Type = "oneshot";
      path = [ pkgs.acl ];
      script = ''
        setfacl -m g:greeter:rx ${home}
        setfacl -m g:greeter:rx ${home}/.config
        setfacl -R -m g:greeter:rX ${home}/.config/DankMaterialShell
        # Live symlinks under DankMaterialShell point into the flake checkout.
        setfacl -m g:greeter:rx ${home}/.dotfiles
        setfacl -m g:greeter:rx ${flakeRoot}
        setfacl -R -m g:greeter:rX ${dmsConfigDir}
      '';
    };
  };
}
