# Mini — LLM hosting (vLLM-XPU + optional llama.cpp)

Mini runs **vLLM-XPU** when **`miniLlmHosting = true`**. **Chat** on **`8000`** is **[Qwen/Qwen3.5-9B](https://huggingface.co/Qwen/Qwen3.5-9B)** (dense **text** chat) via **`vllm-xpu-chat`** (see `hosts/mini/services/vllm-xpu.nix`). Wiring follows upstream [nixos-overlay.md](https://github.com/jasonboukheir/vllm-xpu-nix/blob/main/docs/nixos-overlay.md) (`parts/hosts.nix` imports **`nixosModules.default`**). For **image/video** inputs, change **`services.vllm-xpu.instances.chat.model`** to a VL checkpoint (e.g. **[Qwen/Qwen3-VL-8B-Instruct](https://huggingface.co/Qwen/Qwen3-VL-8B-Instruct)**) and set **`languageModelOnly = false`** plus **`limitMmPerPrompt`**. Optional **GGUF** on **`8010`** is **`./llama-cpp.nix`**, gated by **`miniLlamaCppGemma`** in `hosts/mini/host.nix` (off by default so the same GPU is not double-booked).

| Stack | File | Port | Model | Role |
|-------|------|------|-------|------|
| **vLLM-XPU** | `hosts/mini/services/vllm-xpu.nix` | **`8000`** chat | [Qwen/Qwen3.5-9B](https://huggingface.co/Qwen/Qwen3.5-9B) (text) | Intel XPU / IPEX path |
| **llama.cpp** (optional) | `hosts/mini/services/llama-cpp.nix` | **`8010`** | [unsloth/gemma-4-12b-it-GGUF](https://huggingface.co/unsloth/gemma-4-12b-it-GGUF) `Q4_K_M` | GGUF chat (Vulkan) when `miniLlamaCppGemma = true` |

**Chat (`8000`):** **`package = pkgs.vllm-xpu-unstable.withTorchvision true`** because Qwen3.5's vLLM class imports Qwen VL image-processing code during inspection, **`quantization = null`** because vLLM's FP8 W8A8 path is not supported on Intel GPU/XPU, **`kvCacheDtype = null`** while stabilising boot, **`languageModelOnly = true`** (skips vision encoder profiling), **`enforceEager = true`**, **`reasoningParser = qwen3`**. Default **`maxModelLen = 8192`**, **`maxNumSeqs = 1`**, **`gpuMemoryUtilization = 0.95`**. If **`journalctl`** shows **`Available KV cache memory: X GiB`** with **X > 0**, raise **`maxModelLen`**. If **X < 0**, lower **`maxModelLen`**. See [model card](https://huggingface.co/Qwen/Qwen3.5-9B).

Tune **`maxModelLen`** after a successful boot using **`Available KV cache memory`** in **`journalctl -u vllm-xpu-chat`**. There is **no** vLLM **STT** instance in the default `vllm-xpu.nix`; add **`instances.stt`** if you want **`8002`**.

**Other vLLM chat checkpoints:** Edit **`services.vllm-xpu.instances.chat.*`** in `hosts/mini/services/vllm-xpu.nix` (e.g. Gemma 4 QAT, Gemma 3 GPTQ) — see **`docs/hosts/mini-vllm-xpu.md`** for Gemma 4 **`gemma4_unified`** / Transformers pitfalls.

While **`miniBootstrap = true`** (first install), the flake skips `vllm-xpu-nix`, `./vllm-xpu.nix`, and `./llama-cpp.nix`. After §5.4 in `mini-install.md`, set **`miniBootstrap = false`**.

**`miniLlmHosting`** in `hosts/mini/host.nix` gates vLLM + optional llama and requires **`ca-derivations`** on the evaluating Nix (see `docs/hosts/mini-vllm-xpu.md`).

## Default services on mini

| Service | Enabled | Notes |
|---------|---------|-------|
| `vllm-xpu-chat` | **yes** | **Qwen3.5-9B** on **8000** — `servedName` **`qwen3.5-9b`** |
| `vllm-xpu-embedding` | **no** | Disabled for now so chat gets the whole XPU memory budget; re-enable `instances.embedding` if `:8001` is needed |
| `llama-cpp-gemma` | **if** `miniLlamaCppGemma` | GGUF on **8010** — set **`true`** in `host.nix` only when chat is **not** also on vLLM |

## Clients and frontends

mini ships a **browser UI** ([Open WebUI](https://github.com/open-webui/open-webui), `hosts/mini/services/open-webui.nix`) **and** the raw **OpenAI-compatible HTTP API**. Both are exposed on the **Tailscale tailnet** (`mini.quokka-qilin.ts.net`) and firewalled off the public internet — `modules/nixos/networking.nix` trusts only `tailscale0`, so the only public port is `:22`.

| What | URL |
|------|-----|
| **Web chat (Open WebUI)** | **`https://mini.quokka-qilin.ts.net`** — from any tailnet host's browser. HTTPS via `tailscale serve` (auto-renewed cert); first account created becomes admin |
| Chat / completions API | **`http://mini:8000/v1`** (tailnet) or **`http://127.0.0.1:8000/v1`** (on mini) — model id = **`servedName`** (e.g. **`qwen3.5-9b`**) |
| Embeddings | **`http://mini:8001/v1`** — model **`jina-embeddings-v5-nano`** (when enabled) |

**How it fits together:** vLLM binds **`0.0.0.0`** (`instances.chat.host` in `vllm-xpu.nix`) so other hosts can use the raw API directly — **no auth** on vLLM, but tailnet-only. Open-WebUI listens on **loopback `:8080`**; `tailscale serve` (the `tailscale-serve-open-webui` oneshot) terminates TLS at the MagicDNS name and proxies to it. **IDEs and agents** (Cursor, Continue, Aider, …) point their OpenAI base URL at `http://mini:8000/v1` from any tailnet host — no SSH tunnel needed. Open-WebUI also re-exports an OpenAI-compatible API at `https://mini.quokka-qilin.ts.net/api` gated by per-user keys, if you prefer authenticated access. The **§ SSH tunnels** below are now only needed from hosts **not** on the tailnet.

## Command reference

From the flake repo on mini (or over SSH), use **`just switch`** after editing Nix (see `docs/hosts/mini-install.md`). For flakes, **`git add`** tracked files before eval-only commands if your workflow requires it.

### Remote management (from any other host)

Author and **commit + push** flake changes on your dev host, then drive mini over SSH — these `just` recipes `git pull --ff-only` on mini and build **there** (run from any host that can `ssh mini`; off-LAN use `MINI_SSH=mini.quokka-qilin.ts.net`):

```bash
just mini pull           # git pull --ff-only on mini (no build)
just mini deploy         # pull + nh switch (the usual remote deploy)
just mini deploy-dry     # pull + build-dry (preview, no activation)
just mini deploy-boot    # pull + stage for next reboot (kernel/bootloader changes)
just mini ssh            # interactive shell on mini
just mini reboot         # reboot the host
just mini llm bench      # rigorous llama-benchy run against http://mini:8000/v1
```

> **Structure:** mini commands are a `just` **module** (`just/mini.just` + `just/mini-llm.just`, wired via `mod mini` in the root `Justfile`). Host ops are `just mini <cmd>`; LLM service ops are nested under `just mini llm <cmd>`. Because module recipes appear as `mini::…` in `just --summary`, the recipe picker's host-scoping (which only matched the old `mini-*` flat names) no longer hides them — so they show on **every** host. Run `just --list mini` / `just --list mini llm` to see them. The LLM ops still operate the services *on mini* (systemctl/journals/`127.0.0.1`); `deploy*`/`pull`/`ssh`/`reboot`/`llm bench` target mini over the network.

`deploy` uses `switch-fast` (no flake check / no commit on mini, since you authored upstream); run `deploy-dry` first if you want a pre-flight build. The `vllm-xpu-kernels` rebuild caveat (`NIX_CONFIG='cores = 2'`, see `mini-vllm-xpu.md`) still applies to the build that runs on mini.

### systemd — status, logs, control

```bash
# List vLLM-related units (names include chat / embedding when enabled)
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

**`Unit vllm-xpu-chat.service not found`:** **`instances.chat.enable`** follows **`vllm-chat-enable`** in `hosts/mini/services/vllm-xpu.nix`. If **`false`**, no unit is generated — set **`true`** and **`just switch`**.

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

### SSH — watch what vLLM is doing

**Interactive:** `ssh jadee@<mini-ip>`, then on mini use **`journalctl`** (below) and **`intel_gpu_top`** (installed on mini) to see logs vs GPU load.

**One-shot from your laptop** (no login shell — you get a stream until Ctrl+C):

```bash
ssh -t jadee@<mini-ip> 'sudo journalctl -fu vllm-xpu-chat'
# second terminal for the embedder (starts after chat per unit ordering):
ssh -t jadee@<mini-ip> 'sudo journalctl -fu vllm-xpu-embedding'
```

**GPU only** (whether vLLM is exercising the dGPU):

```bash
ssh -t jadee@<mini-ip> 'sudo intel_gpu_top'
```

vLLM’s OpenAI server does **not** expose a built-in “dashboard” over HTTP by default in this flake; **logs + GPU top** are the practical live views over SSH.

### APIs — list models

```bash
curl -s http://127.0.0.1:8000/v1/models | jq   # Qwen3.5-9B (vLLM chat)
# curl -s http://127.0.0.1:8001/v1/models | jq # embeddings disabled for chat VRAM
curl -s http://127.0.0.1:8010/v1/models | jq   # GGUF (llama.cpp) — only if enabled
```

Use each stack’s **`servedName`** in API calls: **`qwen3.5-9b`** (vLLM chat on **8000**). If you re-enable embeddings, its served name is **`jina-embeddings-v5-nano`**. If you enable optional llama.cpp, give it a **different** `--alias` than **`qwen3.5-9b`** so clients never see duplicate model ids.

### APIs — chat (Qwen3.5-9B, vLLM on 8000)

For smoke tests, keep generation tiny and disable Qwen thinking. Long prompts with thinking enabled can look stuck on mini even while logs show low generation throughput.

```bash
curl -sS --max-time 120 -N http://127.0.0.1:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "qwen3.5-9b",
    "messages": [{"role": "user", "content": "Reply with exactly: ok"}],
    "max_tokens": 8,
    "stream": true,
    "chat_template_kwargs": {"enable_thinking": false}
  }'
```

### APIs — chat with image (VL checkpoint only)

The default **`Qwen/Qwen3.5-9B`** chat model is **text-only**. For **image** / **video** in **`/v1/chat/completions`**, change **`hosts/mini/services/vllm-xpu.nix`** to a **VL** repo (e.g. **`Qwen/Qwen3-VL-8B-Instruct`**), set **`languageModelOnly = false`**, and add **`limitMmPerPrompt`** (see **`docs/hosts/mini-vllm-xpu.md`**). Example shape (after that switch):

```bash
curl -sS --max-time 600 http://127.0.0.1:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "<your-vl-servedName>",
    "messages": [{
      "role": "user",
      "content": [
        {"type": "text", "text": "Describe the image briefly."},
        {"type": "image_url", "image_url": {"url": "https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/beignets-task-guide.png"}}
      ]
    }],
    "max_tokens": 128,
    "stream": false
  }' | jq .
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

Embeddings are disabled for now so **Qwen3.5-9B** gets the full XPU memory budget. To restore **`:8001`**, set **`services.vllm-xpu.instances.embedding.enable = true`** in `hosts/mini/services/vllm-xpu.nix`, then switch.

### APIs — troubleshooting (no output, hangs, `jq`)

| Symptom | What to try |
|---------|-------------|
| **No output for a long time** | If logs show **`Running: 1 reqs`** and very low generation throughput, the request is alive but too slow. `just mini llm chat` waits up to **300s** for `/v1/models` before sending the smoke request; override with **`MINI_LLM_WAIT_SECONDS=<seconds>`**. First run **`just mini llm status`** and confirm the runtime flags include **`--language-model-only`**, **`--enforce-eager`**, and **`--max-num-seqs 8`**. If not, the host is not running this repo's mini tuning — `git add -A && just switch`, then restart chat. For smoke tests use **`max_tokens: 8`** plus **`chat_template_kwargs: {"enable_thinking": false}`**. Stop the client with Ctrl-C; if the unit keeps generating, run **`just mini llm restart chat`**. |
| **`jq` prints nothing** | Do not pipe SSE streaming responses into `jq`; use raw/streaming output. For one complete JSON response, force **`"stream": false`** and wait for completion. |
| **HTTP / TLS errors** | Confirm **`/v1/models`** works first (§ list models), then inspect logs with **`just mini llm logs chat`**. |
| **Empty `choices[0].message.content`** | With **`reasoningParser = qwen3`**, thinking may appear under **`delta.reasoning`** / structured fields; inspect raw JSON/SSE. Disable thinking in the client via **`chat_template_kwargs`** if you want answers only in **`message.content`** (see [Qwen3.5 model card](https://huggingface.co/Qwen/Qwen3.5-9B)). |

```bash
# Minimal debug: no jq; stream raw SSE
curl -sS --max-time 120 -N \
  -H 'Content-Type: application/json' \
  -d '{"model":"qwen3.5-9b","messages":[{"role":"user","content":"Reply with exactly: ok"}],"max_tokens":8,"stream":true,"chat_template_kwargs":{"enable_thinking":false}}' \
  http://127.0.0.1:8000/v1/chat/completions
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

All services share the **same Intel GPU**. Do **not** run **`vllm-xpu-chat`** and **`llama-cpp-gemma`** together unless you know VRAM fits — keep **`miniLlamaCppGemma = false`** when using vLLM chat (default in `host.nix`). If you ever enable both stacks, give them **different** `--alias` / `servedName` values so OpenAI clients do not see two models with the same id.

Optional llama.cpp’s Hugging Face cache lives under **`/var/lib/llama-cpp/huggingface`** when that module is enabled.

`vllm-xpu-embedding` is currently disabled so chat can claim the full XPU memory
budget. If you re-enable it, order it after `vllm-xpu-chat` and bind it to chat
so it cannot keep an XPU allocation while chat reloads the larger model.

## Switching chat backend

| Goal | `hosts/mini/host.nix` | `hosts/mini/services/vllm-xpu.nix` |
|------|------------------------|---------------------------|
| **vLLM chat on 8000** (default) | `miniLlamaCppGemma = false` | `vllm-chat-enable = true`, `models.chat.repo` / `instances.chat.*` as desired |
| **GGUF Gemma on 8010** only | `miniLlamaCppGemma = true` | `vllm-chat-enable = false` |

Then **`just switch`**.

## Change GGUF quant (llama.cpp only)

Edit `hosts/mini/services/llama-cpp.nix` (`modelQuant`, `contextSize`, `gpuLayers`), ensure **`miniLlamaCppGemma = true`**, then **`just switch`**.

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

Edit **`hosts/mini/services/vllm-xpu.nix`** (`models.chat.repo`, `instances.chat.*`), then **`just switch`**. Deep troubleshooting (KV OOM, ccache, kernel params) lives in **`docs/hosts/mini-vllm-xpu.md`**.
