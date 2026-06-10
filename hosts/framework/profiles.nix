{...}: {
  dotfiles.profiles = {
    devenv.enable = true;
    devgui.enable = true;
    apps.enable = true;
    desktop.loginManager = "dms-greeter";
    desktop.enable = true;
  };
}
