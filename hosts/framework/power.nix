{pkgs, ...}: {
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
    # Use flake pkgs (overlay) — bundled framework-control flake still pins a stale fetchFromGitHub hash.
    framework-control = {
      enable = true;
      package = pkgs.framework-control;
    };
    power-profiles-daemon.enable = true;
    fwupd.enable = true;
    blueman.enable = true;
  };
}
