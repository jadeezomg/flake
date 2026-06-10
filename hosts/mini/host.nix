let
  inherit (import ../lib.nix) sharedNixOSHost sharedNixOSUser;
in
  sharedNixOSHost
  // {
    hostname = "mini";
    description = "Mini — Minisforum MS-01 headless server";
    user = sharedNixOSUser;
    # First `nixos-install`: set `true` — skips sops password file + vLLM-XPU / llama.cpp.
    # (no `vllm-xpu-nix` module / `./vllm-xpu.nix` + `./llama-cpp.nix`, so evaluators without
    # `ca-derivations` still build). Flip to `false` after docs/hosts/mini-install.md §5.4.
    miniBootstrap = false;
    # Gates `vllm-xpu-nix`, `./vllm-xpu.nix`, and `./llama-cpp.nix`. The generic
    # `dotfiles.profiles.llm` serving stack defaults off and is unused on mini.
    miniLlmHosting = true;
    # When false, skip `./llama-cpp.nix` — use when Gemma chat is served by vLLM on 8000
    # instead of llama.cpp on 8010 (same GPU; both on will OOM).
    miniLlamaCppGemma = false;
    # GGML backends for nixpkgs `llama-cpp` (Vulkan + CLBlast/OpenCL only — not SYCL/OpenVINO).
    # Use `vulkan-opencl` to compile both, then pick GPU at runtime via `LLAMA_ARG_DEVICE` or
    # `systemctl edit llama-cpp-gemma` (see docs/hosts/mini-llm-hosting.md).
    miniLlamaCppGgmlBackends = "vulkan";
    # Optional `LLAMA_ARG_DEVICE` for llama-server (null = auto). List: `llama-server --list-devices`.
    miniLlamaCppDevice = null;
    # No guest accounts on a headless server.
    extraUsers = [];
    # 24 GiB RAM: keep local builds conservative. The installer has no disk
    # swap and large Rust/Node derivations can OOM at higher parallelism.
    buildCores = 4;
    # Disabled until sbctl keys exist on the installed host. Flip to true in git
    # after `sudo sbctl create-keys`, then switch to let lanzaboote sign /boot.
    secureBoot = false;
    stateVersion = "26.05";
    # Note: mainMonitor / dmsSettingsFile / niriOutputsFile intentionally omitted.
    # the desktop profile (disabled here) carries the desktop HM tree.
  }
