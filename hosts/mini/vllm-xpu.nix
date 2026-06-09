# Intel XPU vLLM — ported from ~/.dotfiles/examples/dotfiles hosts/brutus/services/vllm-xpu.nix
# (Brutus: Arc B50-class + vllm-xpu-nix). See docs/hosts/mini-vllm-xpu.md.
# Optional GGUF on 8010: `./llama-cpp.nix` when `host.miniLlamaCppGemma` (see `host.nix`).
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.vllm-xpu;
  chat = cfg.instances.chat;
  embedding = cfg.instances.embedding;
  stt = cfg.instances.stt;

  # examples/dotfiles uses homelab.ports; this flake has no homelab module — fixed ports.
  ports = {
    local-llm = 8000;
    local-embedding = 8001;
    local-stt = 8002;
  };

  models = {
    # Gemma 4 12B IT — official QAT W4A16 compressed-tensors (Google; aimed at vLLM).
    # If this revision fails on Intel XPU (unsupported arch in pinned vllm-xpu), try
    # ISTA-DASLab/gemma-3-12b-it-GPTQ-4b-128g (Gemma 3) until upstream catches up.
    chat = {
      repo = "google/gemma-4-12B-it-qat-w4a16-ct";
    };
    embedding = {
      repo = "jinaai/jina-embeddings-v5-text-nano-retrieval";
      rev = "ac5d898c8d382b17167c33e5c8af644a3519b47d";
    };
    stt = {
      repo = "distil-whisper/distil-large-v3.5";
      rev = "728a7691f3ff1d3d971528d3203a6e9559165d41";
    };
  };

  # Gemma 4 12B QAT on XPU — set `miniLlamaCppGemma = false` in host.nix so 8010 llama.cpp
  # is off (same GPU as vLLM chat + embedding).
  vllm-chat-enable = true;
  vllm-embedding-enable = true;
in {
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

  services.vllm-xpu = {
    package = (pkgs.vllm-xpu-unstable.withTorchvision true).withKernelConfig {
      chunkPrefill = "chunk_prefill_default";
      chunkPrefillExtra = [
        "256,true,true,false,false,false"
        "256,false,true,false,false,false"
        "256,false,true,false,false,true"
      ];
      pagedDecode = "paged_decode_default";
      pagedDecodeExtra = [
        "8,256,16,true,false,false"
        "8,256,32,true,false,false"
        "8,256,64,true,false,false"
        "8,256,64,false,false,false"
      ];
    };

    instances.chat = {
      enable = vllm-chat-enable;
      port = lib.mkIf chat.enable ports.local-llm;
      host = "127.0.0.1";

      model = models.chat.repo;
      servedName = "gemma-4-12b-it";
      dtype = "bfloat16";
      # Weights use `quantization_config.quant_method = compressed-tensors` in the repo;
      # omit `--quantization` so vLLM follows the checkpoint.
      quantization = null;
      kvCacheDtype = "fp8";
      maxModelLen = 16384;
      maxNumSeqs = 8;
      gpuMemoryUtilization = 0.88;
      speculativeConfig = null;
      enforceEager = false;
      enableXpuGraph = true;
      cudagraphCaptureSizes = [
        3
        6
      ];
      reasoningParser = null;
      enableAutoToolChoice = false;
      toolCallParser = null;
      languageModelOnly = true;
      extraArgs = ["--trust-remote-code"];
    };

    instances.embedding = {
      enable = vllm-embedding-enable;
      port = lib.mkIf embedding.enable ports.local-embedding;
      host = "127.0.0.1";

      runner = "pooling";
      model = models.embedding.repo;
      servedName = "jina-embeddings-v5-nano";
      maxModelLen = 8192;
      maxNumSeqs = 8;
      gpuMemoryUtilization = 0.05;
      enforceEager = true;
      extraArgs = ["--trust-remote-code"];
    };

    instances.stt = {
      enable = false;
      port = lib.mkIf stt.enable ports.local-stt;
      host = "127.0.0.1";

      model = models.stt.repo;
      servedName = "distil-large-v3.5";
      dtype = "bfloat16";
      maxModelLen = 448;
      maxNumSeqs = 32;
      limitMmPerPrompt = {
        audio = 1;
      };
      kvCacheDtype = "fp8";
      gpuMemoryUtilization = 0.05;
      enforceEager = true;
      attentionBackend = "TRITON_ATTN";
    };
  };

  # Let chat claim VRAM before the embedder starts profiling (when chat is enabled).
  systemd.services.vllm-xpu-embedding = {
    after = ["vllm-xpu-chat.service"];
    wants = ["vllm-xpu-chat.service"];
  };

  # Avoid devenv's generic llama-cpp hosting profile — mini uses ./llama-cpp.nix instead.
  dotfiles.profiles.devenv.llm.hosting.enable = lib.mkForce false;
}
