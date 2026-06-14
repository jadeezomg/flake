# Intel XPU vLLM — consumption matches upstream:
# https://github.com/jasonboukheir/vllm-xpu-nix/blob/main/docs/nixos-overlay.md
# (`nixosModules.default` is imported in `hosts/mini/default.nix` when `miniLlmHosting`.)
# Host-specific tuning, ccache, and optional kernel overrides: `docs/hosts/mini-vllm-xpu.md`.
# Optional GGUF on 8010: `./llama-cpp.nix` when `host.miniLlamaCppGemma` (see `host.nix`).
{
  config,
  lib,
  pkgs,
  ...
}: {
  # Brutus graphics stack: OpenCL/L0 + media — needed for Intel discrete Arc / Xe compute.
  hardware.graphics.extraPackages = with pkgs; [
    intel-compute-runtime
    intel-compute-runtime.drivers
    intel-media-driver
    vpl-gpu-rt
  ];

  environment.systemPackages = [pkgs.intel-gpu-tools];

  # Battlemage-class discrete GPU: same probe as examples/brutus. Remove if you have no dGPU.
  boot.kernelParams = ["xe.force_probe=e223"];

  # vllm-xpu-kernels compile through ccache by default (upstream useCcache = true).
  # Without a sandbox-visible, nixbld-writable cache dir, icpx fails with
  # "ccache: error: Permission denied". See vllm-xpu-nix docs/build.md.
  systemd.tmpfiles.rules = [
    "d /var/cache/ccache 0770 root nixbld - -"
  ];
  nix.settings.extra-sandbox-paths = lib.mkAfter ["/var/cache/ccache"];

  # Hugging Face Hub auth (`secrets/secrets.yaml` → `hf_token`): rate limits + downloads.
  sops.secrets.hf_token = {};
  sops.templates."mini-llm-hf.env" = {
    mode = "0400";
    content = ''
      HF_TOKEN=${config.sops.placeholder.hf_token}
      HUGGING_FACE_HUB_TOKEN=${config.sops.placeholder.hf_token}
    '';
  };

  services.vllm-xpu = {
    # Qwen3.5 text import still loads qwen3_vl -> transformers qwen2_vl image
    # processing at model-inspection time; keep torchvision in the closure even
    # with `languageModelOnly = true`.
    package = pkgs.vllm-xpu-unstable.withTorchvision true;

    instances.chat = {
      enable = true;
      environmentFile = config.sops.templates."mini-llm-hf.env".path;

      # Arc Pro B50 has only ~15 GiB: unquantized Qwen3.5-9B (bf16 ~18 GiB) cannot
      # fit at any gpuMemoryUtilization. Use Intel's int4 AutoRound build (~5 GiB
      # weights) — same pattern as the reference brutus `Intel/...-int4-AutoRound`.
      # Packs as `auto_round:auto_gptq`, so it loads via the gptq path.
      model = "Intel/Qwen3.5-9B-int4-AutoRound";
      servedName = "qwen3.5-9b";
      dtype = "bfloat16";
      quantization = "gptq";
      kvCacheDtype = null;
      languageModelOnly = true;
      maxModelLen = 8192;
      maxNumSeqs = 1;
      gpuMemoryUtilization = 0.85;
      speculativeConfig = null;
      enforceEager = true;
      enableXpuGraph = false;
      reasoningParser = "qwen3";
      enableAutoToolChoice = false;
      toolCallParser = null;
      extraArgs = [
        "--trust-remote-code"
        "--revision"
        "29688b8959bebb6d019ddd8f174a5b4bfd670456"
      ];
    };

    # Disabled while tuning chat: Qwen3.5 gets the whole XPU memory budget.
    instances.embedding = {
      enable = false;
      port = 8001;
      environmentFile = config.sops.templates."mini-llm-hf.env".path;

      runner = "pooling";
      model = "jinaai/jina-embeddings-v5-text-nano-retrieval";
      servedName = "jina-embeddings-v5-nano";
      maxModelLen = 8192;
      maxNumSeqs = 8;
      gpuMemoryUtilization = 0.05;
      enforceEager = true;
      extraArgs = [
        "--trust-remote-code"
        "--revision"
        "ac5d898c8d382b17167c33e5c8af644a3519b47d"
      ];
    };
  };
}
