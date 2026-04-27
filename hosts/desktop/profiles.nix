{...}: {
  dotfiles.profiles = {
    devenv.enable = true;
    apps.enable = true;
    gaming.enable = true;
    essentials.promptEngine = "starship";
  };
}
