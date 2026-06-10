{...}: {
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
    # The generic LLM serving stack (dotfiles.profiles.llm) defaults off and
    # stays off here — mini serves via ./vllm-xpu.nix / ./llama-cpp.nix.
  };
}
