# Local LLM chat stack for mini — one serving contract, two interchangeable
# backends. Imported as a whole (gated by `host.miniLlmHosting`) from
# `hosts/mini/default.nix`; the backend is selected here by `host.miniLlmBackend`.
#
# This module is both the aggregator AND the shared base every backend needs (the
# Intel GPU stack + the Hugging Face token), since those are always present too.
# Exactly one backend is imported (shared GPU; both would OOM), and both honour the
# same contract (`host.miniLlm{ServedName,Port,Host}`) so consumers (open-webui,
# honcho) can't tell them apart:
#   "vllm"     → vllm-xpu-nix module + ./vllm-xpu.nix  (Intel XPU, Qwen3.5-9B int4)
#   "llamacpp" → ./llama-cpp.nix                       (Vulkan, Gemma-4-12B GGUF)
# The chat frontend (`./open-webui.nix`) is always imported and is backend-agnostic.
{
  config,
  inputs,
  lib,
  pkgs,
  host,
  ...
}: let
  backend = host.miniLlmBackend or "vllm";
in {
  imports =
    [./open-webui.nix]
    ++ lib.optionals (backend == "vllm") [
      # vllm-xpu-nix: `nixosModules.default` = overlay + `services.vllm-xpu` (see upstream
      # https://github.com/jasonboukheir/vllm-xpu-nix/blob/main/docs/nixos-overlay.md ).
      inputs.vllm-xpu-nix.nixosModules.default
      ./vllm-xpu.nix
    ]
    ++ lib.optionals (backend == "llamacpp") [
      ./llama-cpp.nix
    ];

  # --- shared base: needed by both backends, so it lives in the always-present aggregator ---

  # Intel discrete Arc / Xe graphics stack: OpenCL/L0 + media. vLLM-XPU needs the
  # compute runtime; llama.cpp's Vulkan path rides Mesa (from the base GPU profile)
  # but the extra packages are harmless when llama.cpp is the active backend.
  hardware.graphics.extraPackages = with pkgs; [
    intel-compute-runtime
    intel-compute-runtime.drivers
    intel-media-driver
    vpl-gpu-rt
  ];

  environment.systemPackages = [pkgs.intel-gpu-tools];

  # Battlemage-class discrete GPU: same probe as examples/brutus. Remove if you have
  # no dGPU. Needed by both backends — without it neither vLLM nor Vulkan sees the card.
  boot.kernelParams = ["xe.force_probe=e223"];

  # Hugging Face Hub auth (`secrets/secrets.yaml` → `hf_token`): rate limits + downloads.
  # Both `vllm-xpu` and `llama-cpp` load this env file (`EnvironmentFile` / `environmentFile`).
  sops.secrets.hf_token = {};
  sops.templates."mini-llm-hf.env" = {
    mode = "0400";
    content = ''
      HF_TOKEN=${config.sops.placeholder.hf_token}
      HUGGING_FACE_HUB_TOKEN=${config.sops.placeholder.hf_token}
    '';
  };
}
