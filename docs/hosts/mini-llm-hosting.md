# Mini — LLM hosting (vLLM-XPU + optional llama.cpp)

Mini runs **vLLM-XPU** when **`miniLlmHosting = true`**. **Gemma-class chat** is served on **`8000`** via **`vllm-xpu-chat`** (see `hosts/mini/vllm-xpu.nix`). Optional **GGUF** on **`8010`** is **`./llama-cpp.nix`**, gated by **`miniLlamaCppGemma`** in `hosts/mini/host.nix` (off by default so the same GPU is not double-booked).

| Stack | File | Port | Model | Role |
|-------|------|------|-------|------|
| **vLLM-XPU** | `hosts/mini/vllm-xpu.nix` | **`8000`** chat, `8001` embed, `8002` STT | [google/gemma-4-12B-it-qat-w4a16-ct](https://huggingface.co/google/gemma-4-12B-it-qat-w4a16-ct) (QAT W4A16 compressed-tensors), Jina embeddings | Intel XPU / IPEX path |
| **llama.cpp** (optional) | `hosts/mini/llama-cpp.nix` | **`8010`** | [unsloth/gemma-4-12b-it-GGUF](https://huggingface.co/unsloth/gemma-4-12b-it-GGUF) `Q4_K_M` | GGUF chat (Vulkan) when `miniLlamaCppGemma = true` |

**Quant choice (Gemma 4 12B, vLLM):** Default chat weights are **`google/gemma-4-12B-it-qat-w4a16-ct`** — Google’s QAT **W4A16** in **compressed-tensors**, explicitly aimed at **vLLM** (see the model card). **Do not** run this and **AWQ**-style Gemma 3 ports for “smaller VRAM” without checking compatibility: Gemma 3 + AWQ had ecosystem quality issues; Gemma 4 should use Google’s QAT CT line or another vLLM-documented checkpoint.

**Fallback (Gemma 3):** If your pinned **vllm-xpu** build errors on **`Gemma4UnifiedForConditionalGeneration`**, switch `models.chat.repo` to **`ISTA-DASLab/gemma-3-12b-it-GPTQ-4b-128g`** and `servedName` to **`gemma-3-12b-it`** until XPU catches up.

While **`miniBootstrap = true`** (first install), the flake skips `vllm-xpu-nix`, `./vllm-xpu.nix`, and `./llama-cpp.nix`. After §5.4 in `mini-install.md`, set **`miniBootstrap = false`**.

**`miniLlmHosting`** in `hosts/mini/host.nix` gates vLLM + optional llama and requires **`ca-derivations`** on the evaluating Nix (see `docs/hosts/mini-vllm-xpu.md`).

## Default services on mini

| Service | Enabled | Notes |
|---------|---------|-------|
| `vllm-xpu-chat` | **yes** | Gemma 4 12B IT QAT W4A16 on **8000** — `servedName` **`gemma-4-12b-it`** |
| `vllm-xpu-embedding` | **yes** | Jina embeddings on **8001** |
| `llama-cpp-gemma` | **if** `miniLlamaCppGemma` | GGUF on **8010** — set **`true`** in `host.nix` only when chat is **not** also on vLLM |

## Command reference

From the flake repo on mini (or over SSH), use **`just switch`** after editing Nix (see `docs/hosts/mini-install.md`). For flakes, **`git add`** tracked files before eval-only commands if your workflow requires it.

### systemd — status, logs, control

```bash
# List vLLM-related units (names include chat / embedding / stt when enabled)
systemctl list-units 'vllm-xpu-*' --all
```

```bash
sudo systemctl status vllm-xpu-chat vllm-xpu-embedding
# When llama.cpp is enabled:
sudo systemctl status vllm-xpu-chat vllm-xpu-embedding llama-cpp-gemma

# Follow logs
sudo journalctl -fu vllm-xpu-chat           # first start: HF download + compile
sudo journalctl -fu vllm-xpu-embedding
sudo journalctl -fu llama-cpp-gemma         # only if unit exists

sudo journalctl -u vllm-xpu-chat -u vllm-xpu-embedding -e --no-pager
```

**`Unit vllm-xpu-chat.service not found`:** **`instances.chat.enable`** follows **`vllm-chat-enable`** in `hosts/mini/vllm-xpu.nix`. If **`false`**, no unit is generated — set **`true`** and **`just switch`**.

```bash
# Start / stop / restart
sudo systemctl restart vllm-xpu-chat
sudo systemctl restart vllm-xpu-embedding
sudo systemctl restart llama-cpp-gemma    # only if imported

sudo systemctl stop vllm-xpu-chat
sudo systemctl start vllm-xpu-chat
```

```bash
# Disable / enable on boot (prefer changing Nix + `just switch` for durability)
sudo systemctl disable --now llama-cpp-gemma
sudo systemctl enable --now llama-cpp-gemma
```

### APIs — list models

```bash
curl -s http://127.0.0.1:8000/v1/models | jq   # Gemma 4 (vLLM chat)
curl -s http://127.0.0.1:8001/v1/models | jq   # Jina embeddings (vLLM)
curl -s http://127.0.0.1:8010/v1/models | jq   # GGUF (llama.cpp) — only if enabled
```

Use each stack’s **`servedName`** in API calls: **`gemma-4-12b-it`** (vLLM chat on **8000**), **`jina-embeddings-v5-nano`** (embeddings). Optional llama.cpp also defaults its **`--alias`** to **`gemma-4-12b-it`** — do **not** use the same alias if both stacks are ever enabled; pick a distinct name in `llama-cpp.nix`.

### APIs — chat (Gemma 4, vLLM on 8000)

```bash
curl -s http://127.0.0.1:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "gemma-4-12b-it",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 64
  }' | jq
```

### APIs — chat (GGUF on 8010, when `miniLlamaCppGemma`)

```bash
curl -s http://127.0.0.1:8010/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "gemma-4-12b-it",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 64
  }' | jq
```

### APIs — embeddings (Jina)

```bash
curl -s http://127.0.0.1:8001/v1/embeddings \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "jina-embeddings-v5-nano",
    "input": "hello"
  }' | jq
```

### SSH tunnels (APIs bind `127.0.0.1` only)

```bash
# vLLM chat + embeddings (default mini)
ssh -L 8000:127.0.0.1:8000 -L 8001:127.0.0.1:8001 jadee@<mini-ip>

# Add GGUF on 8010 when llama.cpp is enabled
ssh -L 8000:127.0.0.1:8000 -L 8001:127.0.0.1:8001 -L 8010:127.0.0.1:8010 jadee@<mini-ip>
```

### GPU memory (shared Intel dGPU)

```bash
intel_gpu_top
```

## VRAM / coexistence

All services share the **same Intel GPU**. Do **not** run **`vllm-xpu-chat`** (HF Gemma 4 CT weights) and **`llama-cpp-gemma`** (separate GGUF) together unless you know VRAM fits — keep **`miniLlamaCppGemma = false`** when using vLLM chat (default in `host.nix`). If you ever enable both stacks, give them **different** `--alias` / `servedName` values so OpenAI clients do not see two models with the same id.

Optional llama.cpp’s Hugging Face cache lives under **`/var/lib/llama-cpp/huggingface`** when that module is enabled.

## Switching chat backend

| Goal | `hosts/mini/host.nix` | `hosts/mini/vllm-xpu.nix` |
|------|------------------------|---------------------------|
| **vLLM Gemma on 8000** (default) | `miniLlamaCppGemma = false` | `vllm-chat-enable = true`, `models.chat.repo` as desired |
| **GGUF Gemma on 8010** only | `miniLlamaCppGemma = true` | `vllm-chat-enable = false` |

Then **`just switch`**.

## Change GGUF quant (llama.cpp only)

Edit `hosts/mini/llama-cpp.nix` (`modelQuant`, `contextSize`, `gpuLayers`), ensure **`miniLlamaCppGemma = true`**, then **`just switch`**.

Other quants: `Q3_K_M` (~5.4 GiB), `Q5_K_M` (~8 GiB), `IQ4_XS` (~6 GiB).

## Change vLLM chat model

Edit **`hosts/mini/vllm-xpu.nix`** (`models.chat.repo`, `instances.chat.*`), then **`just switch`**. Deep troubleshooting (KV OOM, ccache, kernel params) lives in **`docs/hosts/mini-vllm-xpu.md`**.
