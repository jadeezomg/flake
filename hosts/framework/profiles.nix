{ ... }: {
  dotfiles.hardware = {
    wireless.enable = true;
    gpu = "amd";
    cpu.zen4.enable = true;
  };

  dotfiles.profiles = {
    devenv.enable = true;
    devgui.enable = true;
    apps.enable = true;
    desktop.shell = "noctalia";
    desktop.loginManager = "gdm"; # required for noctalia
    desktop.enable = true;
  };
}
