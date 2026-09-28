_: {
  dotfiles.hardware = {
    # Intel iGPU + Arc Pro B50 dGPU (llama.cpp stack under ./services/llm/).
    gpu = "intel";
    wireless.enable = true;
  };

  dotfiles.profiles = {
    # hostClass "server" (hosts/hosts.nix) already defaults desktop,
    # integrations, fonts.full and theme.gui to off; see modules/profiles/server.nix.
    server.enable = true;
    devenv.enable = true;
  };
}
