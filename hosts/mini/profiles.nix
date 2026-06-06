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
    # Same knob as `host.miniLlmHosting` (see `hosts/mini/host.nix`): when false,
    # no Vulkan llama-cpp; when true, `./vllm-xpu.nix` still forces this off to
    # avoid two GPU LLM stacks (vLLM-XPU replaces hosting packages).
    devenv.llm.hosting.enable = lib.mkForce (host.miniLlmHosting or false);
  };
}
