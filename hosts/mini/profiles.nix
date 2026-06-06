{
  host,
  lib,
  ...
}: {
  dotfiles.profiles = {
    server.enable = true;

    # Headless: opt out of every desktop-flavoured profile explicitly.
    desktop.enable = false;
    integrations.enable = false;
    apps.enable = false;
    devenv.enable = true;
    gaming.enable = false;
    work.enable = false;
    devenv.languages.swift.enable = false;
    # When `miniLlmHosting` is false: force hosting off (no Vulkan llama-cpp).
    # When true: do not set here — `./vllm-xpu.nix` `mkForce`s hosting off vs vLLM-XPU;
    # two `mkForce`s on the same option would conflict.
    devenv.llm.hosting.enable = lib.mkIf (!(host.miniLlmHosting or false)) (lib.mkForce false);
  };
}
