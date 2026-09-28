_: {
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
    # LLM toolbox: unsloth-studio + llama.cpp CLI + hf CLI. The llama.cpp build
    # follows `hardware.gpu = "nvidia"`, so it is CUDA (built from source unless
    # cache.nixos-cuda.org has it). Set `llm.llamaCppBackend` only to override.
    llm.tools.enable = true;
  };
}
