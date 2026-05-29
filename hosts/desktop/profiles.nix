{...}: {
  dotfiles.profiles = {
    devenv.enable = true;
    apps.enable = true;
    gaming.enable = true;
    desktop.loginManager = "dms-greeter";
  };
}
