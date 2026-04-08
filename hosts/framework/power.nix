{...}: {
  hardware = {
    bluetooth.enable = true;
    fw-fanctrl = {
      enable = true;
      config = {
        defaultStrategy = "laziest";
        strategyOnDischarging = "laziest";
      };
    };
  };

  services = {
    framework-control.enable = true;
    power-profiles-daemon.enable = true;
    fwupd.enable = true;
    blueman.enable = true;
  };
}
