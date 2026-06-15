# Mini — LLM hosting (one chat stack, two interchangeable backends)

Mini runs **one local chat stack** when **`miniLlmHosting = true`**, served on a **single shared contract** no matter which backend is active. The contract lives in `hosts/mini/host.nix` and is read by both backends **and** every consumer:

| Contract value | `host.nix` | Meaning |
|----------------|------------|---------|
| **served model id** | `miniLlmServedName = "local-chat"` | the OpenAI model id clients request — **model-neutral on purpose** so consumers do not change when you switch backends |
| **port** | `miniLlmPort = 8000` | **both** backends serve here |
| **bind** | `miniLlmHost = "0.0.0.0"` | tailnet bind (both backends) |

The active backend is chosen by **one toggle** in `hosts/mini/host.nix`:

```nix
miniLlmBackend = "vllm";      # default — Intel XPU vLLM
# miniLlmBackend = "llamacpp"; # alternative — GGUF via llama.cpp (Vulkan)
```

**Exactly one backend runs at a time** — they share the Intel GPU and running both would OOM. The two backends are interchangeable at the **API level** (same model id, port, host); only the underlying model differs (a deliberate choice — the API surface is unified, not the model). Wiring follows upstream [nixos-overlay.md](https://github.com/jasonboukheir/vllm-xpu-nix/blob/main/docs/nixos-overlay.md) (`hosts/mini/default.nix` imports **`nixosModules.default`** when the vLLM backend is active). For **image/video** inputs on the vLLM backend, change **`services.vllm-xpu.instances.chat.model`** to a VL checkpoint (e.g. **[Qwen/Qwen3-VL-8B-Instruct](https://huggingface.co/Qwen/Qwen3-VL-8B-Instruct)**) and set **`languageModelOnly = false`** plus **`limitMmPerPrompt`**.

| Backend | `miniLlmBackend` | File | Unit | Model (advertised as `local-chat`) | Role |
|---------|------------------|------|------|------------------------------------|------|
| **vLLM-XPU** | `"vllm"` (default) | `hosts/mini/services/llm/vllm-xpu.nix` | `vllm-xpu-chat` | [Intel/Qwen3.5-9B-int4-AutoRound](https://huggingface.co/Intel/Qwen3.5-9B-int4-AutoRound) (text) | Intel XPU / IPEX path |
| **llama.cpp** | `"llamacpp"` | `hosts/mini/services/llm/llama-cpp.nix` | `llama-cpp-gemma` | [unsloth/gemma-4-12b-it-GGUF](https://huggingface.co/unsloth/gemma-4-12b-it-GGUF) `Q4_K_M` | GGUF chat (Vulkan) |

**Shared module:** whichever backend is active, the stack aggregator **`hosts/mini/services/llm/default.nix`** is always imported when **`miniLlmHosting`** (`hosts/mini/default.nix` imports the single **`./services/llm`** folder, which resolves to it). It carries the shared base both backends need — the Intel GPU stack, the **`xe.force_probe`** kernel param, and the **`mini-llm-hf.env`** Hugging Face token sops template. (These previously lived inside `llm/vllm-xpu.nix`.) `hosts/mini/services/llm/open-webui.nix` is always imported by it too.

**Chat (`8000`):** **`package = pkgs.vllm-xpu-unstable.withTorchvision true`** because Qwen3.5's vLLM class imports Qwen VL image-processing code during inspection, **`quantization = null`** because vLLM's FP8 W8A8 path is not supported on Intel GPU/XPU, **`kvCacheDtype = null`** while stabilising boot, **`languageModelOnly = true`** (skips vision encoder profiling), **`enforceEager = true`**, **`reasoningParser = qwen3`**. Default **`maxModelLen = 8192`**, **`maxNumSeqs = 1`**, **`gpuMemoryUtilization = 0.95`**. If **`journalctl`** shows **`Available KV cache memory: X GiB`** with **X > 0**, raise **`maxModelLen`**. If **X < 0**, lower **`maxModelLen`**. See [model card](https://huggingface.co/Qwen/Qwen3.5-9B).

Tune **`maxModelLen`** after a successful boot using **`Available KV cache memory`** in **`journalctl -u vllm-xpu-chat`**. There is **no** vLLM **STT** instance in the default `vllm-xpu.nix`; add **`instances.stt`** if you want **`8002`**.

**Other vLLM chat checkpoints:** Edit **`services.vllm-xpu.instances.chat.*`** in `hosts/mini/services/llm/vllm-xpu.nix` (e.g. Gemma 4 QAT, Gemma 3 GPTQ) — see **`docs/hosts/mini-vllm-xpu.md`** for Gemma 4 **`gemma4_unified`** / Transformers pitfalls.

While **`miniBootstrap = true`** (first install), the flake skips the whole `./services/llm` folder (`llm/default.nix` and its shared base), `vllm-xpu-nix`, `./llm/vllm-xpu.nix`, and `./llm/llama-cpp.nix`. After §5.4 in `mini-install.md`, set **`miniBootstrap = false`**.

**`miniLlmHosting`** in `hosts/mini/host.nix` gates the whole chat stack. The **vLLM** backend additionally requires **`ca-derivations`** on the evaluating Nix (see `docs/hosts/mini-vllm-xpu.md`); the **llama.cpp** backend does not.

## Default services on mini

The active chat unit depends on **`miniLlmBackend`** — exactly one of the two chat units runs.

| Service | Enabled | Notes |
|---------|---------|-------|
| `vllm-xpu-chat` | **when** `miniLlmBackend = "vllm"` (default) | Serves [Intel/Qwen3.5-9B-int4-AutoRound](https://huggingface.co/Intel/Qwen3.5-9B-int4-AutoRound) on **8000** — advertised as **`local-chat`** |
| `llama-cpp-gemma` | **when** `miniLlmBackend = "llamacpp"` | Serves [unsloth/gemma-4-12b-it-GGUF](https://huggingface.co/unsloth/gemma-4-12b-it-GGUF) on **8000** — advertised as **`local-chat`** |
| `vllm-xpu-embedding` | **no** | Disabled for now so chat gets the whole XPU memory budget; re-enable `instances.embedding` if `:8001` is needed (vLLM backend only) |

## Clients and frontends

mini ships a **browser UI** ([Open WebUI](https://github.com/open-webui/open-webui), `hosts/mini/services/llm/open-webui.nix`) **and** the raw **OpenAI-compatible HTTP API**. Both are exposed on the **Tailscale tailnet** (`mini.quokka-qilin.ts.net`) and firewalled off the public internet — `modules/nixos/networking.nix` trusts only `tailscale0`, so the only public port is `:22`.

| What | URL |
|------|-----|
| **Web chat (Open WebUI)** | **`https://mini.quokka-qilin.ts.net`** — from any tailnet host's browser. HTTPS via `tailscale serve` (auto-renewed cert); first account created becomes admin |
| Chat / completions API | **`http://mini:8000/v1`** (tailnet) or **`http://127.0.0.1:8000/v1`** (on mini) — model id = **`local-chat`** regardless of backend |
| Embeddings | **`http://mini:8001/v1`** — model **`jina-embeddings-v5-nano`** (vLLM backend only, when enabled) |

**How it fits together:** whichever backend is active binds **`0.0.0.0`** on **8000** (`miniLlmHost` / `miniLlmPort` from the shared contract) so other hosts can use the raw API directly — **no auth** on the chat server, but tailnet-only. Open-WebUI listens on **loopback `:8080`**; `tailscale serve` (the `tailscale-serve-open-webui` oneshot) terminates TLS at the MagicDNS name and proxies to it. **IDEs and agents** (Cursor, Continue, Aider, …) point their OpenAI base URL at `http://mini:8000/v1` from any tailnet host — no SSH tunnel needed. Open-WebUI also re-exports an OpenAI-compatible API at `https://mini.quokka-qilin.ts.net/api` gated by per-user keys, if you prefer authenticated access. The **§ SSH tunnels** below are now only needed from hosts **not** on the tailnet.

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

The chat unit name depends on **`miniLlmBackend`**: **`vllm-xpu-chat`** for `"vllm"`, **`llama-cpp-gemma`** for `"llamacpp"`. Only the active backend's unit exists.

```bash
# List units for whichever backend is active
systemctl list-units 'vllm-xpu-*' --all     # vLLM backend (chat / embedding)
systemctl status llama-cpp-gemma            # llama.cpp backend
```

```bash
# vLLM backend
sudo systemctl status vllm-xpu-chat vllm-xpu-embedding
# llama.cpp backend
sudo systemctl status llama-cpp-gemma

# Follow logs
sudo journalctl -fu vllm-xpu-chat           # first start: HF download + compile
sudo journalctl -fu vllm-xpu-embedding      # vLLM backend, when embeddings enabled
sudo journalctl -fu llama-cpp-gemma         # llama.cpp backend

sudo journalctl -u vllm-xpu-chat -u vllm-xpu-embedding -e --no-pager
```

**`Unit vllm-xpu-chat.service not found`:** the vLLM backend is not active (or `instances.chat.enable` / **`vllm-chat-enable`** is **`false`** in `hosts/mini/services/llm/vllm-xpu.nix`). Set **`miniLlmBackend = "vllm"`** (and `vllm-chat-enable = true`), then **`just switch`**. If you wanted GGUF, look for **`llama-cpp-gemma`** instead.

```bash
# Start / stop / restart (use the unit for your active backend)
sudo systemctl restart vllm-xpu-chat
sudo systemctl restart vllm-xpu-embedding   # vLLM backend, when enabled
sudo systemctl restart llama-cpp-gemma

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
curl -s http://127.0.0.1:8000/v1/models | jq   # active chat backend — always advertises `local-chat`
# curl -s http://127.0.0.1:8001/v1/models | jq # embeddings disabled for chat VRAM (vLLM backend only)
```

Use the shared served id **`local-chat`** in all chat API calls — it is the same whether the active backend is vLLM or llama.cpp, so consumers never change when you switch backends. If you re-enable embeddings (vLLM backend only), its served name is **`jina-embeddings-v5-nano`**.

### APIs — chat (`local-chat` on 8000)

For smoke tests, keep generation tiny and disable Qwen thinking. Long prompts with thinking enabled can look stuck on mini even while logs show low generation throughput. (Thinking-control flags below apply to the vLLM/Qwen backend; the llama.cpp/Gemma backend ignores them.)

```bash
curl -sS --max-time 120 -N http://127.0.0.1:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "local-chat",
    "messages": [{"role": "user", "content": "Reply with exactly: ok"}],
    "max_tokens": 8,
    "stream": true,
    "chat_template_kwargs": {"enable_thinking": false}
  }'
```

### APIs — chat with image (VL checkpoint only)

The default vLLM-backend chat model (**`Intel/Qwen3.5-9B-int4-AutoRound`**) is **text-only**. For **image** / **video** in **`/v1/chat/completions`**, change **`hosts/mini/services/llm/vllm-xpu.nix`** to a **VL** repo (e.g. **`Qwen/Qwen3-VL-8B-Instruct`**), set **`languageModelOnly = false`**, and add **`limitMmPerPrompt`** (see **`docs/hosts/mini-vllm-xpu.md`**). The served id stays **`local-chat`**. Example shape (after that switch):

```bash
curl -sS --max-time 600 http://127.0.0.1:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "local-chat",
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

### APIs — chat (llama.cpp backend, `miniLlmBackend = "llamacpp"`)

When the llama.cpp backend is active it serves on the **same** port **8000** and the **same** served id **`local-chat`** — the request is byte-for-byte identical to the vLLM backend, so consumers do not change:

```bash
curl -s http://127.0.0.1:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "local-chat",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 64
  }' | jq
```

### APIs — embeddings (Jina)

Embeddings are part of the **vLLM backend** and are disabled for now so chat gets the full XPU memory budget. To restore **`:8001`**, set **`services.vllm-xpu.instances.embedding.enable = true`** in `hosts/mini/services/llm/vllm-xpu.nix` (with `miniLlmBackend = "vllm"`), then switch.

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
  -d '{"model":"local-chat","messages":[{"role":"user","content":"Reply with exactly: ok"}],"max_tokens":8,"stream":true,"chat_template_kwargs":{"enable_thinking":false}}' \
  http://127.0.0.1:8000/v1/chat/completions
```

### SSH tunnels (only needed from non-tailnet hosts)

The chat API binds **`0.0.0.0`** on the tailnet, so any tailnet peer can hit **`http://mini:8000/v1`** directly — no tunnel needed. From a host that is **not** on the tailnet, forward the ports over SSH:

```bash
# chat (8000, both backends) + embeddings (8001, vLLM backend when enabled)
ssh -L 8000:127.0.0.1:8000 -L 8001:127.0.0.1:8001 jadee@<mini-ip>
```

### GPU memory (shared Intel dGPU)

```bash
intel_gpu_top
```

## VRAM / coexistence

All services share the **same Intel GPU**. The two chat backends are **mutually exclusive** — **`miniLlmBackend`** picks exactly one, so **`vllm-xpu-chat`** and **`llama-cpp-gemma`** are never imported together (running both would OOM the shared GPU). There is no longer an "additive optional llama.cpp" stack; switching backend means swapping which single chat unit owns the GPU.

The llama.cpp backend's Hugging Face cache lives under **`/var/lib/llama-cpp/huggingface`** when that backend is active.

`vllm-xpu-embedding` is currently disabled so chat can claim the full XPU memory
budget. If you re-enable it, order it after `vllm-xpu-chat` and bind it to chat
so it cannot keep an XPU allocation while chat reloads the larger model.

## Switching chat backend

One toggle in `hosts/mini/host.nix` selects the backend. Both serve **`local-chat`** on **8000** bound to **`0.0.0.0`** — consumers do not change.

| Goal | `hosts/mini/host.nix` | Per-backend tuning |
|------|------------------------|--------------------|
| **vLLM chat** (default) | `miniLlmBackend = "vllm"` | `hosts/mini/services/llm/vllm-xpu.nix`: `vllm-chat-enable = true`, `models.chat.repo` / `instances.chat.*` as desired |
| **GGUF Gemma via llama.cpp** | `miniLlmBackend = "llamacpp"` | `hosts/mini/services/llm/llama-cpp.nix`: `modelQuant`, `contextSize`, `gpuLayers` as desired |

Then **`just switch`**. The shared contract (`miniLlmServedName` / `miniLlmPort` / `miniLlmHost`) is unchanged across the switch.

## Change GGUF quant (llama.cpp backend only)

Edit `hosts/mini/services/llm/llama-cpp.nix` (`modelQuant`, `contextSize`, `gpuLayers`), ensure **`miniLlmBackend = "llamacpp"`**, then **`just switch`**.

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

Edit **`hosts/mini/services/llm/vllm-xpu.nix`** (`models.chat.repo`, `instances.chat.*`), then **`just switch`**. Deep troubleshooting (KV OOM, ccache, kernel params) lives in **`docs/hosts/mini-vllm-xpu.md`**.
