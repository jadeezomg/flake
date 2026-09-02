_: {
  # bluetooth lives in dotfiles.hardware.bluetooth (profiles.nix).
  hardware = {
    fw-fanctrl = {
      enable = true;
      config = {
        defaultStrategy = "laziest";
        strategyOnDischarging = "laziest";
      };
    };
  };

  services.power-profiles-daemon.enable = true;
}
