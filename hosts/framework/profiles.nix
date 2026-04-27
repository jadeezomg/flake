{...}: {
  dotfiles.profiles = {
    devenv.enable = true;
    apps.enable = true;
    essentials.promptEngine = "starship";
  };
}
