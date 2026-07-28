{ ... }: {
  dotfiles.hardware = {
    # No radio module in the desktop (wired ethernet only).
    gpu = "nvidia";
    cpu.zen4.enable = true;
    cpu.x3d.enable = true;
  };

  dotfiles.profiles = {
    devenv.enable = true;
    devgui.enable = true;
    apps.enable = true;
    gaming.enable = true;
    desktop.loginManager = "gdm";
    desktop.shell = "noctalia";
    # LLM serving stack: unsloth-studio + llama.cpp with CUDA (NVIDIA box;
    # builds from source — not in the public binary cache).
    llm.enable = true;
    llm.llamaCppBackend = "cuda";
  };
}
