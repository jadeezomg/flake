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
            # Deliberately no `Environment=PATH=…` here. systemd does not expand
            # variables in Environment=, so a `…:$PATH` entry appends the literal
            # string and destroys the inherited PATH — which left noctalia unable
            # to find systemctl/loginctl, so its session buttons logged
            # "no supported command found" and did nothing. Units inherit the
            # full session PATH from the user manager (niri.service and the
            # autostart units all show /run/current-system/sw/bin), and the
            # plugin binaries come from home.packages in ./noctalia/default.nix.
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
