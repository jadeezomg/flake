{
  config,
  pkgs,
  user,
  lib,
  ...
}:
let
  loginManager = config.dotfiles.profiles.desktop.loginManager;
in
{
  # --- DMS greeter config sync (loginManager = "dms-greeter") ---
  users.users.${user}.extraGroups = lib.optionals (loginManager == "dms-greeter") [ "greeter" ];

  # ACL: grant greeter group read access to user's home for DMS config sync.
  # Equivalent of `dms greeter sync` which is unavailable on NixOS.
  systemd.services.dms-greeter-acl = lib.mkIf (loginManager == "dms-greeter") {
    description = "Set ACL permissions for DMS greeter config sync";
    before = [ "greetd.service" ];
    wantedBy = [ "graphical.target" ];
    serviceConfig.Type = "oneshot";
    path = [ pkgs.acl ];
    script = ''
      setfacl -m g:greeter:rx /home/${user}
      setfacl -m g:greeter:rx /home/${user}/.config
      setfacl -R -m g:greeter:rX /home/${user}/.config/DankMaterialShell
    '';
  };
}
