{ ... }: {
  dotfiles.hardware = {
    # Intel iGPU + Arc Pro B50 dGPU (llama.cpp stack under ./services/llm/).
    gpu = "intel";
    wireless.enable = true;
  };

  dotfiles.profiles = {
    server.enable = true;

    # Headless: opt out of every desktop-flavoured profile explicitly.
    desktop.enable = false;
    integrations.enable = false;
    apps.enable = false;
    fonts.full.enable = false;
    theme.gui.enable = false;
    devenv.enable = true;
    gaming.enable = false;
    work.enable = false;
    devenv.languages.swift.enable = false;
  };
}
