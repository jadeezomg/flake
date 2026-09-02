# Local LLM serving on mini. Turns on the shared llama.cpp router
# (modules/profiles/llm/serve.nix) with mini's models and adds the Open WebUI
# frontend (./open-webui.nix). Imported from hosts/mini/default.nix when
# `host.miniLlmHosting` is true.
#
# The GPU stack (Intel compute runtime, media driver) comes from the hardware
# trait `dotfiles.hardware.gpu = "intel"` (modules/profiles/hardware/gpu-intel.nix).
# The llama-cpp build is Vulkan, derived from that trait. The HF token template
# `mini-llm-hf.env` lives in hosts/mini/secrets.nix.
#
# Two presets today, both resident (`--models-max 2`), each an OpenAI model id:
#   [local-chat]  unsloth/gemma-4-12B-it-qat-GGUF, Gemma 4 12B QAT (UD-Q4_K_XL)
#                 plus vision (mmproj-*.gguf).
#   [local-embed] mradermacher/F2LLM-v2-0.6B-GGUF, Qwen3-arch embedding model
#                 for /v1/embeddings.
# See docs/hosts/mini.md § LLM stack.
{ config, ... }:
{
  imports = [ ./open-webui.nix ];

  dotfiles.profiles.llm.serve = {
    enable = true;

    # Tailnet bind: the firewall trusts only tailscale0 (modules/nixos/networking.nix),
    # so this is tailnet-only, never public. Loopback consumers still reach it.
    host = "0.0.0.0";
    port = 8000;
    threads = 8;

    # Optional GPU pin (`LLAMA_ARG_DEVICE`); null = auto. List: `llama-server --list-devices`.
    device = null;

    # Hugging Face Hub auth: rate limits and downloads.
    environmentFile = config.sops.templates."mini-llm-hf.env".path;

    models = {
      # Chat: Gemma 4 12B QAT plus vision. UD-Q4_K_XL is the only quant in the
      # QAT repo. Higher precision degrades QAT weights.
      #
      # KV budget on the 15 GiB Arc B50: QAT ~6.7 + mmproj ~1 + embedder ~0.6 +
      # overhead ~1.5 ≈ 9.8 GB used, leaving ~5.2 GB for chat KV. Gemma 4 is cheap
      # on KV (only 8 of 48 layers are full-attention; the rest cap at a 1024
      # sliding window), ~32 KiB/token at q8_0, so 128K ≈ 4.2 GB with ~1 GB margin.
      # `ctx` is the TOTAL pool split across `slots` (each conversation gets
      # ctx/slots). Verify on the box (journalctl prints the KV size; intel_gpu_top
      # shows VRAM). There is room to push toward the model's 256K train length.
      local-chat = {
        hfRepo = "unsloth/gemma-4-12B-it-qat-GGUF";
        quant = "UD-Q4_K_XL";
        mmprojAuto = true;
        ctx = 131072; # 128K total, 64K per conversation at 2 slots
        slots = 2;
        kvType = "q8_0";
        flashAttn = "on";
        settings = {
          jinja = true;
          temp = "1.0";
          top-p = "0.95";
          top-k = 64;
        };
      };

      # Embeddings: 1024-dim, last-token pooling (Qwen3-arch embedders).
      local-embed = {
        hfRepo = "mradermacher/F2LLM-v2-0.6B-GGUF";
        quant = "Q8_0";
        embedding = true;
        pooling = "last";
        ctx = 8192;
      };
    };
  };
}
