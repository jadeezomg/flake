{...}: {
  dotfiles.profiles = {
    server.enable = true;

    # Headless: opt out of every desktop-flavoured profile explicitly.
    desktop.enable = false;
    integrations.enable = false;
    apps.enable = false;
    devenv.enable = false;
    gaming.enable = false;
    work.enable = false;
  };
}
