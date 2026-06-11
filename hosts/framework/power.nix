{pkgs, ...}: {
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

  services = {
    # Use flake pkgs (overlay) — bundled framework-control flake still pins a stale fetchFromGitHub hash.
    framework-control = {
      enable = true;
      package = pkgs.framework-control;
    };
    power-profiles-daemon.enable = true;
    fwupd.enable = true;
  };
}
