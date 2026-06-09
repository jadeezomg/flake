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
    # Gates `vllm-xpu-nix`, `./vllm-xpu.nix`, `./llama-cpp.nix`, and `devenv.llm.hosting`
    # (`profiles.nix`). `./vllm-xpu.nix` still `mkForce`s devenv hosting off vs ./llama-cpp.nix.
    miniLlmHosting = true;
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
    # `home/nixos/default.nix` skips the desktop HM tree when mainMonitor is unset.
  }
