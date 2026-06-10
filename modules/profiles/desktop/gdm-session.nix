{
  lib,
  osConfig,
  pkgs,
  ...
}: let
  useGdm = (osConfig.dotfiles.profiles.desktop.loginManager or "dms-greeter") == "gdm";
  desktopEnabled = osConfig.dotfiles.profiles.desktop.enable or false;
  dmsPackage = osConfig.programs.dank-material-shell.package or pkgs.dms-shell;
in {
  config = lib.mkIf (useGdm && desktopEnabled) {
    # NixOS installs dms/dsearch as system-wide user units; GDM greeter sessions
    # inherit graphical-session.target and break login. Scope to the HM user instead.
    systemd.user.services = {
      dms = {
        Unit = {
          Description = "DankMaterialShell";
          After = ["graphical-session.target"];
          PartOf = ["graphical-session.target"];
        };
        Service = {
          ExecStart = "${dmsPackage}/bin/dms run --session";
          Restart = "on-failure";
        };
        Install = {
          WantedBy = ["graphical-session.target"];
        };
      };

      dsearch = {
        Unit = {
          Description = "dsearch - Fast filesystem search service";
          Documentation = ["https://github.com/AvengeMedia/dsearch"];
          After = ["network.target"];
        };
        Service = {
          Type = "simple";
          ExecStart = "${pkgs.dsearch}/bin/dsearch serve";
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install = {
          WantedBy = ["default.target"];
        };
      };
    };
  };
}
