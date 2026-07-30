{
  config,
  host,
  lib,
  ...
}:
let
  cfg = config.dotfiles.profiles.desktop;
  useGdm = cfg.loginManager == "gdm";

  monitorsFile = host.gdmMonitorsFile or null;
  monitors = ./. + "/${monitorsFile}";

  # GDM 49+ no longer runs the greeter out of `$HOME/.config`. It builds the
  # greeter's XDG_CONFIG_HOME as `/var/lib/gdm/<seat>/config` (see the
  # `/var/lib/gdm/%s/config` format string in gdm's binary), so the two paths
  # every guide still recommends — /var/lib/gdm/.config and the greeter's own
  # ~/.config under /run/gdm/home — are simply never read. The /run path is
  # doubly useless: GDM removes that home when the greeter session ends.
  #
  # Single seat here, so target seat0 directly.
  greeterConfigDir = "/var/lib/gdm/seat0/config";

  # Note: the greeter's HM session units live in ../gdm-session.nix, which stays
  # beside noctalia/ because it imports that app's extra-packages helper.
in
{
  config = lib.mkIf (cfg.enable && useGdm) {
    services.displayManager.gdm.enable = true;

    # Give the greeter the same physical layout the session uses; mutter has no
    # other way to learn about it. See monitors-desktop.xml for the constraints.
    systemd.tmpfiles.rules = lib.mkIf (monitorsFile != null) [
      "d ${greeterConfigDir} 0700 gdm-greeter gdm"
      "L+ ${greeterConfigDir}/monitors.xml - - - - ${monitors}"
    ];
  };
}
