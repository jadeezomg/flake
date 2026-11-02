_: {
  dotfiles.hardware = {
    wireless.enable = true;
    gpu = "amd";
    cpu.zen4.enable = true;
  };

  dotfiles.profiles = {
    devenv.enable = true;
    devgui.enable = true;
    apps.enable = true;
    gaming.enable = true;
    theme.variant = "black";
    desktop = {
      shell = "noctalia";
      loginManager = "gdm"; # input.nix has fingerprint PAM rules for gdm, none for noctalia-greeter
    };
  };
}
