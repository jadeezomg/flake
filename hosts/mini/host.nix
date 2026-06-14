let
  inherit (import ../lib.nix) sharedNixOSHost sharedNixOSUser;
in
  sharedNixOSHost
  // {
    hostname = "mini";
    description = "Mini — Minisforum MS-01 headless server";
    user = sharedNixOSUser;
    # Gates `vllm-xpu-nix`, `./vllm-xpu.nix`, and `./llama-cpp.nix`. The generic
    # `dotfiles.profiles.llm` serving stack defaults off and is unused on mini.
    miniLlmHosting = true;
    # When false, skip `./llama-cpp.nix` — use when Gemma chat is served by vLLM on 8000
    # instead of llama.cpp on 8010 (same GPU; both on will OOM).
    miniLlamaCppGemma = false;
    # Honcho shared-memory server (./services/honcho.nix). Needs `miniLlmHosting`
    # since its deriver uses the local vLLM model. See docs/hosts/mini-agent-memory-plan.md.
    miniMemoryHosting = true;
    # GGML backends for nixpkgs `llama-cpp` (Vulkan + CLBlast/OpenCL only — not SYCL/OpenVINO).
    # Use `vulkan-opencl` to compile both, then pick GPU at runtime via `LLAMA_ARG_DEVICE` or
    # `systemctl edit llama-cpp-gemma` (see docs/hosts/mini-llm-hosting.md).
    miniLlamaCppGgmlBackends = "vulkan";
    # Optional `LLAMA_ARG_DEVICE` for llama-server (null = auto). List: `llama-server --list-devices`.
    miniLlamaCppDevice = null;
    # No guest accounts on a headless server.
    extraUsers = [];
    # 24 GiB RAM: vllm-xpu kernel TUs can peak around 7 GiB RSS each, and
    # upstream builds them with ninja -j$NIX_BUILD_CORES. Keep this at 2 so
    # `attn-kernels-xe-2` does not OOM-kill icpx during local rebuilds.
    buildCores = 2;
    # Disabled until sbctl keys exist on the installed host. Flip to true in git
    # after `sudo sbctl create-keys`, then switch to let lanzaboote sign /boot.
    secureBoot = false;
    stateVersion = "26.05";
    # Note: mainMonitor / dmsSettingsFile / niriOutputsFile intentionally omitted.
    # the desktop profile (disabled here) carries the desktop HM tree.
  }
