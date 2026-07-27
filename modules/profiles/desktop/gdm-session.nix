{
  lib,
  osConfig,
  pkgs,
  inputs,
  ...
}:
let
  shell = osConfig.dotfiles.profiles.desktop.shell or "dms";
  useGdm = (osConfig.dotfiles.profiles.desktop.loginManager or "dms-greeter") == "gdm";
  dmsPackage = osConfig.programs.dank-material-shell.package or pkgs.dms-shell;
  noctaliaPackage =
    osConfig.programs.noctalia.package
      or inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  config = lib.mkIf useGdm (
    lib.mkMerge [
      (lib.mkIf (shell == "dms") {
        systemd.user.services.dms = {
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
      })
      (lib.mkIf (shell == "noctalia") {
        systemd.user.services.noctalia = {
          Unit = {
            Description = "Noctalia";
            Documentation = [ "https://docs.noctalia.dev/v5/" ];
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
          };
          Service = {
            ExecStart = "${lib.getExe noctaliaPackage}";
            Restart = "on-failure";
          };
          Install = {
            WantedBy = [ "graphical-session.target" ];
          };
        };
      })
    ]
  );
}
