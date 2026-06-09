# Mini — LLM hosting (vLLM-XPU + optional llama.cpp)

Mini runs **vLLM-XPU** when **`miniLlmHosting = true`**. **Chat** on **`8000`** is **[Qwen/Qwen3.6-35B-A3B-FP8](https://huggingface.co/Qwen/Qwen3.6-35B-A3B-FP8)** via **`vllm-xpu-chat`** (see `hosts/mini/vllm-xpu.nix`). Optional **GGUF** on **`8010`** is **`./llama-cpp.nix`**, gated by **`miniLlamaCppGemma`** in `hosts/mini/host.nix` (off by default so the same GPU is not double-booked).

| Stack | File | Port | Model | Role |
|-------|------|------|-------|------|
| **vLLM-XPU** | `hosts/mini/vllm-xpu.nix` | **`8000`** chat, `8001` embed, `8002` STT | [Qwen/Qwen3.6-35B-A3B-FP8](https://huggingface.co/Qwen/Qwen3.6-35B-A3B-FP8) (text + image + video), Jina embeddings | Intel XPU / IPEX path |
| **llama.cpp** (optional) | `hosts/mini/llama-cpp.nix` | **`8010`** | [unsloth/gemma-4-12b-it-GGUF](https://huggingface.co/unsloth/gemma-4-12b-it-GGUF) `Q4_K_M` | GGUF chat (Vulkan) when `miniLlamaCppGemma = true` |

**Chat (`8000`):** **`dtype = auto`**, **`kvCacheDtype = fp8`**, **`reasoningParser = qwen3`**, **`languageModelOnly = false`** so **image + video** inputs work (see [model card](https://huggingface.co/Qwen/Qwen3.6-35B-A3B)). **`limitMmPerPrompt`** caps **`image`** / **`video`** items per prompt (defaults in `vllm-xpu.nix`: 8 images, 1 video) to bound VRAM and engine profiling on a shared GPU with embeddings. **Audio-in** for this checkpoint is not Omni-style; use STT on **`8002`** when enabled.

Tune **`maxModelLen`**, **`maxNumSeqs`**, **`gpuMemoryUtilization`**, and **`limitMmPerPrompt`** in `vllm-xpu.nix` if you hit KV or startup OOM.

**Other vLLM chat checkpoints:** Edit **`models.chat.repo`** and **`instances.chat.*`** (e.g. Gemma 4 QAT, Gemma 3 GPTQ) — see **`docs/hosts/mini-vllm-xpu.md`** for Gemma 4 **`gemma4_unified`** / Transformers pitfalls.

While **`miniBootstrap = true`** (first install), the flake skips `vllm-xpu-nix`, `./vllm-xpu.nix`, and `./llama-cpp.nix`. After §5.4 in `mini-install.md`, set **`miniBootstrap = false`**.

**`miniLlmHosting`** in `hosts/mini/host.nix` gates vLLM + optional llama and requires **`ca-derivations`** on the evaluating Nix (see `docs/hosts/mini-vllm-xpu.md`).

## Default services on mini

| Service | Enabled | Notes |
|---------|---------|-------|
| `vllm-xpu-chat` | **yes** | Qwen3.6 35B-A3B **FP8** VL on **8000** — `servedName` **`qwen3.6-35b-a3b`** |
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
curl -s http://127.0.0.1:8000/v1/models | jq   # Qwen3.6 FP8 (vLLM chat)
curl -s http://127.0.0.1:8001/v1/models | jq   # Jina embeddings (vLLM)
curl -s http://127.0.0.1:8010/v1/models | jq   # GGUF (llama.cpp) — only if enabled
```

Use each stack’s **`servedName`** in API calls: **`qwen3.6-35b-a3b`** (vLLM chat on **8000**), **`jina-embeddings-v5-nano`** (embeddings). If you enable optional llama.cpp, give it a **different** `--alias` than **`qwen3.6-35b-a3b`** so clients never see duplicate model ids.

### APIs — chat (Qwen3.6 FP8, vLLM on 8000)

```bash
curl -s http://127.0.0.1:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "qwen3.6-35b-a3b",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 64
  }' | jq
```

### APIs — chat with image (Qwen3.6 VL on 8000)

Up to **8 images** and **1 video** per prompt (see **`limitMmPerPrompt`** in `hosts/mini/vllm-xpu.nix`). Replace the URL with any **HTTPS** image link reachable from mini.

```bash
curl -s http://127.0.0.1:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "qwen3.6-35b-a3b",
    "messages": [{
      "role": "user",
      "content": [
        {"type": "text", "text": "Describe the image briefly."},
        {"type": "image_url", "image_url": {"url": "https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/beignets-task-guide.png"}}
      ]
    }],
    "max_tokens": 128
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

All services share the **same Intel GPU**. Do **not** run **`vllm-xpu-chat`** (Qwen3.6 MoE + FP8 + **vision**) and **`llama-cpp-gemma`** together unless you know VRAM fits — keep **`miniLlamaCppGemma = false`** when using vLLM chat (default in `host.nix`). If you ever enable both stacks, give them **different** `--alias` / `servedName` values so OpenAI clients do not see two models with the same id.

Optional llama.cpp’s Hugging Face cache lives under **`/var/lib/llama-cpp/huggingface`** when that module is enabled.

## Switching chat backend

| Goal | `hosts/mini/host.nix` | `hosts/mini/vllm-xpu.nix` |
|------|------------------------|---------------------------|
| **vLLM chat on 8000** (default) | `miniLlamaCppGemma = false` | `vllm-chat-enable = true`, `models.chat.repo` / `instances.chat.*` as desired |
| **GGUF Gemma on 8010** only | `miniLlamaCppGemma = true` | `vllm-chat-enable = false` |

Then **`just switch`**.

## Change GGUF quant (llama.cpp only)

Edit `hosts/mini/llama-cpp.nix` (`modelQuant`, `contextSize`, `gpuLayers`), ensure **`miniLlamaCppGemma = true`**, then **`just switch`**.

Other quants: `Q3_K_M` (~5.4 GiB), `Q5_K_M` (~8 GiB), `IQ4_XS` (~6 GiB).

## llama.cpp GGML backends (Vulkan vs OpenCL)

NixOS **`pkgs.llama-cpp`** in nixpkgs builds **Vulkan** and/or **OpenCL (CLBlast)** — not **SYCL** or **OpenVINO** (those need separate CMake flags and Intel stacks; see upstream [SYCL](https://github.com/ggml-org/llama.cpp/blob/master/docs/backend/SYCL.md) and [OpenVINO](https://github.com/ggml-org/llama.cpp/blob/master/docs/backend/OPENVINO.md)). To try those on mini you would need a custom package or an overlay until nixpkgs exposes them.

**Compile-time (one rebuild):** set **`miniLlamaCppGgmlBackends`** in `hosts/mini/host.nix`:

| Value | Effect |
|-------|--------|
| **`vulkan`** | Vulkan only (default). |
| **`vulkan-opencl`** | Vulkan + OpenCL in one binary — lets you compare backends without another rebuild. |
| **`opencl`** | OpenCL (CLBlast) only. |

**Runtime (no rebuild)** when the binary includes both backends (`vulkan-opencl`):

1. List devices on the host after a switch: **`llama-server --list-devices`** (the binary is on **`PATH`** from `environment.systemPackages`).
2. **Without editing the flake:** `sudo systemctl edit llama-cpp-gemma` and add:

   ```ini
   [Service]
   Environment=LLAMA_ARG_DEVICE=YOUR_DEVICE_ID
   ```

   Then `sudo systemctl daemon-reload && sudo systemctl restart llama-cpp-gemma`. Remove the override to return to auto selection.

**From the flake:** set **`miniLlamaCppDevice`** in `host.nix` to the same string (or `null` for auto). That sets **`LLAMA_ARG_DEVICE`** in the unit.

## Change vLLM chat model

Edit **`hosts/mini/vllm-xpu.nix`** (`models.chat.repo`, `instances.chat.*`), then **`just switch`**. Deep troubleshooting (KV OOM, ccache, kernel params) lives in **`docs/hosts/mini-vllm-xpu.md`**.
