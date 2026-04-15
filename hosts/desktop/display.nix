{pkgs, ...}: {
  # Expose monitors.xml at system XDG path so sessions (and GDM) can use it when looking up
  # XDG_CONFIG_DIRS. See GDM #1028 re monitors.xml compatibility.
  # https://gitlab.gnome.org/GNOME/gdm/-/issues/1028
  environment.etc."xdg/monitors.xml" = {
    source = ../../data/hosts/desktop/monitors.xml;
    mode = "0644";
  };

  # Apply monitor layout to GDM login screen from the flake-managed monitors.xml.
  # Copy to both locations: GDM 49+ uses seat0/config; some versions also read ~gdm/.config.
  # Primary monitor is first in monitors.xml so GDM shows the login on that display.
  # https://discourse.nixos.org/t/multi-monitor-gdm-help/60348/6
  systemd.services.applyUserMonitorSettings = let
    gdmSeatConfig = "/var/lib/gdm/seat0/config";
    gdmUserConfig = "/var/lib/gdm/.config";
    monitorsXml = pkgs.writeText "monitors.xml" (builtins.readFile ../../data/hosts/desktop/monitors.xml);
  in {
    description = "Apply monitor settings to GDM login screen";
    before = ["display-manager.service"];
    wantedBy = ["graphical.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c ''
        mkdir -p ${gdmSeatConfig} ${gdmUserConfig}
        cp -f ${monitorsXml} ${gdmSeatConfig}/monitors.xml
        cp -f ${monitorsXml} ${gdmUserConfig}/monitors.xml
        chown -R gdm:gdm ${gdmSeatConfig} ${gdmUserConfig}
      ''";
    };
  };
}
