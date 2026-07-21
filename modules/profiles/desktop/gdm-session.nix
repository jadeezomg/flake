{
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  # osConfig reads here are system *values* (login manager choice, the DMS
  # package), not profile gates — this module is only pushed when the
  # desktop profile is enabled.
  useGdm = (osConfig.dotfiles.profiles.desktop.loginManager or "dms-greeter") == "gdm";
  dmsPackage = osConfig.programs.dank-material-shell.package or pkgs.dms-shell;
in
{
  config = lib.mkIf useGdm {
    # NixOS installs dms as a system-wide user unit; GDM greeter sessions
    # inherit graphical-session.target and break login. Scope to the HM user instead.
    systemd.user.services = {
      dms = {
        Unit = {
          Description = "DankMaterialShell";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${dmsPackage}/bin/dms run --session";
          Restart = "on-failure";
        };
        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };
    };
  };
}
