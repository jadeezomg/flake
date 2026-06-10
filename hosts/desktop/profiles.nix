{...}: {
  dotfiles.profiles = {
    devenv.enable = true;
    devgui.enable = true;
    apps.enable = true;
    gaming.enable = true;
    desktop.loginManager = "dms-greeter";

    # LLM serving stack: unsloth-studio + llama.cpp with CUDA (NVIDIA box;
    # builds from source — not in the public binary cache).
    llm.enable = true;
    llm.llamaCppBackend = "cuda";
  };
}
