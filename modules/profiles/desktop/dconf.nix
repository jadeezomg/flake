# dconf user settings (HM half) — pushed only for desktop hosts: dconf
# activation talks to the user dconf D-Bus service; on headless hosts
# home-manager-<user>.service would fail at "Activating dconfSettings".
{lib, ...}: let
  inherit (lib.hm.gvariant) mkTuple;
in {
  dconf.enable = true;
  dconf.settings = {
    "org/gnome/desktop/input-sources" = {
      sources = [
        (mkTuple ["xkb" "us+intl"])
        (mkTuple ["xkb" "de"])
      ];
      xkb-options = ["compose:ralt"];
    };

    "org/gnome/mutter" = {
      experimental-features = ["scale-monitor-framebuffer"];
    };

    # Reduce GTK decoration font size
    "org/gnome/desktop/wm/preferences" = {
      titlebar-font = "Iosevka Nerd Font 10";
    };
  };
}
