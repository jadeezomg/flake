{
  config,
  dotfilesLib,
  host,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.profiles.desktop;
  useGdm = cfg.loginManager == "gdm";

  # The greeter is its own user with its own dconf database, so none of the
  # user's HM/Stylix theming reaches it — restate the font choices from
  # lib/theme-fonts.nix. Sizes follow Stylix's own convention (documents one
  # step smaller than applications).
  fonts = dotfilesLib.themeFonts { inherit pkgs; };
  appSize = toString fonts.sizes.applications;
  docSize = toString (fonts.sizes.applications - 1);

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

    # Greeter theming. `programs.dconf.profiles.gdm` is the gdm module's own
    # hook, so these merge with its defaults rather than replacing them.
    # Fonts resolve through system fontconfig (the `fonts` profile installs
    # these same packages), so nothing extra is needed on XDG_DATA_DIRS here.
    #
    # Only the font family and base size are settable here: gnome-shell's
    # stylesheet declares no font-family and sizes everything in `em` off
    # `stage { font-size: 1em }`, so it inherits this GTK setting. The greeter's
    # *colours* are the opposite — hardcoded in that stylesheet, unreachable
    # from dconf.
    programs.dconf.profiles.gdm.databases = [
      {
        settings = {
          "org/gnome/desktop/interface" = {
            font-name = "${fonts.sansSerif.name} ${appSize}";
            document-font-name = "${fonts.serif.name} ${docSize}";
            monospace-font-name = "${fonts.monospace.name} ${appSize}";
            color-scheme = "prefer-dark";
          };
          "org/gnome/login-screen".disable-user-list = true;
        };
      }
    ];
  };
}
