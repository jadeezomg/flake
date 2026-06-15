# Intel XPU vLLM — the "vllm" backend of the local chat stack (selected via
# `host.miniLlmBackend = "vllm"` in `host.nix`; the "llamacpp" alternative is
# `./llama-cpp.nix`). Both serve the SAME contract (`host.miniLlm{ServedName,Port,Host}`)
# so consumers can't tell them apart. Shared GPU stack + HF token: `./default.nix`.
# Consumption matches upstream:
# https://github.com/jasonboukheir/vllm-xpu-nix/blob/main/docs/nixos-overlay.md
# Host-specific tuning, ccache, and optional kernel overrides: `docs/hosts/mini-vllm-xpu.md`.
{
  config,
  lib,
  pkgs,
  host,
  ...
}: {
  # vllm-xpu-kernels compile through ccache by default (upstream useCcache = true).
  # Without a sandbox-visible, nixbld-writable cache dir, icpx fails with
  # "ccache: error: Permission denied". See vllm-xpu-nix docs/build.md.
  systemd.tmpfiles.rules = [
    "d /var/cache/ccache 0770 root nixbld - -"
  ];
  nix.settings.extra-sandbox-paths = lib.mkAfter ["/var/cache/ccache"];

  services.vllm-xpu = {
    # Qwen3.5 text import still loads qwen3_vl -> transformers qwen2_vl image
    # processing at model-inspection time; keep torchvision in the closure even
    # with `languageModelOnly = true`.
    package = pkgs.vllm-xpu-unstable.withTorchvision true;

    instances.chat = {
      enable = true;
      environmentFile = config.sops.templates."mini-llm-hf.env".path;

      # Shared serving contract (host.nix) — identical to the llama.cpp backend so
      # consumers (open-webui, honcho) never change. host = tailnet bind; the firewall
      # trusts only tailscale0 (modules/nixos/networking.nix), so it is tailnet-only,
      # never public. Open-WebUI on mini still reaches it over loopback.
      host = host.miniLlmHost;
      port = host.miniLlmPort;
      servedName = host.miniLlmServedName;

      # Arc Pro B50 has only ~15 GiB: unquantized Qwen3.5-9B (bf16 ~18 GiB) cannot
      # fit at any gpuMemoryUtilization. Use Intel's int4 AutoRound build (~5 GiB
      # weights) — same pattern as the reference brutus `Intel/...-int4-AutoRound`.
      # Packs as `auto_round:auto_gptq`, so it loads via the gptq path.
      model = "Intel/Qwen3.5-9B-int4-AutoRound";
      dtype = "bfloat16";
      quantization = "gptq";
      # Qwen3.5 is hybrid linear-attention: only 8 of 32 layers are full attention,
      # so KV is cheap (16 KiB/token at fp8). fp8 KV fits the model's full 262k ctx
      # in ~4 GiB. See docs/hosts/mini-vllm-xpu.md if fp8 KV destabilises boot on XPU.
      kvCacheDtype = "fp8";
      languageModelOnly = true;
      maxModelLen = 131072;
      # Continuous batching: serve up to 8 requests concurrently. KV is cheap here
      # (int4 weights + fp8 KV -> ~398k-token pool, ~3x concurrency headroom), so a
      # single long generation no longer head-of-line-blocks everything behind it.
      maxNumSeqs = 8;
      # B50 is headless (display is on the Iris Xe iGPU), so vLLM can claim more of
      # the card than the reference's 0.85. 0.95 failed the startup free-memory
      # pre-check (needed 15.13 of 15.01 free); 0.90 leaves margin.
      gpuMemoryUtilization = 0.9;
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
