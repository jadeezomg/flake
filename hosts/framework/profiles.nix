{...}: {
  dotfiles.profiles = {
    devenv.enable = true;
    apps.enable = true;
    devenv.llm.hosting.enable = false;
    desktop.loginManager = "dms-greeter";
    desktop.enable = true;
  };
}
