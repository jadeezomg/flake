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
    package = pkgs.vllm-xpu-unstable;

    instances.chat = {
      enable = true;
      environmentFile = config.sops.templates."mini-llm-hf.env".path;

      model = "Qwen/Qwen3.5-9B";
      servedName = "qwen3.5-9b";
      dtype = "bfloat16";
      quantization = "fp8";
      kvCacheDtype = "fp8";
      languageModelOnly = true;
      maxModelLen = 32768;
      maxNumSeqs = 1;
      gpuMemoryUtilization = 0.95;
      speculativeConfig = null;
      enforceEager = true;
      enableXpuGraph = false;
      reasoningParser = "qwen3";
      enableAutoToolChoice = false;
      toolCallParser = null;
      extraArgs = ["--trust-remote-code"];
    };

    instances.embedding = {
      enable = true;
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

  # Let chat claim VRAM before the embedder starts profiling (when chat is enabled).
  systemd.services.vllm-xpu-embedding = {
    after = ["vllm-xpu-chat.service"];
    wants = ["vllm-xpu-chat.service"];
  };
}
