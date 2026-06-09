# Mini — LLM hosting (vLLM-XPU + llama.cpp)

Mini runs **two complementary stacks** when **`miniLlmHosting = true`**:

| Stack | File | Port | Model | Role |
|-------|------|------|-------|------|
| **vLLM-XPU** | `hosts/mini/vllm-xpu.nix` | `8000` chat, `8001` embed, `8002` STT | Qwen3.6-27B int4, Jina embeddings | Intel XPU / IPEX path |
| **llama.cpp** | `hosts/mini/llama-cpp.nix` | **`8010`** | [unsloth/gemma-4-12b-it-GGUF](https://huggingface.co/unsloth/gemma-4-12b-it-GGUF) `Q4_K_M` | GGUF chat (Vulkan) |

GGUF is **not** served by vLLM — llama.cpp is added **alongside** vLLM, not as a replacement.

While **`miniBootstrap = true`** (first install), the flake skips `vllm-xpu-nix`, `./vllm-xpu.nix`, and `./llama-cpp.nix`. After §5.4 in `mini-install.md`, set **`miniBootstrap = false`**.

**`miniLlmHosting`** in `hosts/mini/host.nix` gates both modules and requires **`ca-derivations`** on the evaluating Nix (see `docs/hosts/mini-vllm-xpu.md`).

## Default services on mini

| Service | Enabled | Notes |
|---------|---------|-------|
| `llama-cpp-gemma` | **yes** | Primary chat API — `gemma-4-12b-it` on **8010** |
| `vllm-xpu-embedding` | **yes** | Jina embeddings on **8001** |
| `vllm-xpu-chat` | **no** | Qwen27B OOMs on mini VRAM today; set `vllm-chat-enable = true` in `vllm-xpu.nix` after tuning / GPU upgrade |

## Operating Gemma (llama.cpp)

```bash
sudo systemctl status llama-cpp-gemma
sudo journalctl -fu llama-cpp-gemma   # first start: HF download ~7 GiB
curl -s http://127.0.0.1:8010/v1/models | jq
```

```bash
curl -s http://127.0.0.1:8010/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "gemma-4-12b-it",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 64
  }' | jq
```

## Operating vLLM-XPU

Embeddings (and optional Qwen chat):

```bash
sudo systemctl status vllm-xpu-embedding
curl -s http://127.0.0.1:8001/v1/models | jq
```

Full vLLM notes: **`docs/hosts/mini-vllm-xpu.md`**.

## SSH tunnels

```bash
ssh -L 8010:127.0.0.1:8010 -L 8001:127.0.0.1:8001 jadee@<mini-ip>
```

## VRAM / coexistence

Both stacks share the **same Intel GPU**. Gemma’s Hugging Face cache lives under **`/var/lib/llama-cpp/huggingface`** (owned by the `llama` user; avoids permission issues with `/var/cache`). Running Qwen (vLLM chat) and Gemma (llama.cpp) **at the same time** usually exceeds VRAM on mini.

- Use **Gemma on 8010** for chat (default).
- Keep **vLLM embedding on 8001** alongside Gemma.
- Only enable **`vllm-xpu-chat`** when you stop `llama-cpp-gemma` or have enough VRAM.

```bash
intel_gpu_top
```

## Change Gemma quant

Edit `hosts/mini/llama-cpp.nix` (`modelQuant`, `contextSize`, `gpuLayers`), then `nixos-rebuild switch`.

Other quants: `Q3_K_M` (~5.4 GiB), `Q5_K_M` (~8 GiB), `IQ4_XS` (~6 GiB).
