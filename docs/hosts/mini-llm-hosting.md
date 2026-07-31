# Mini — LLM hosting (llama.cpp router)

Mini runs **one local chat stack** when **`miniLlmHosting = true`**, served on a **single contract** in `hosts/mini/host.nix` and read by every consumer:

| Contract value | `host.nix` | Meaning |
|----------------|------------|---------|
| **served model id** | `miniLlmServedName = "local-chat"` | OpenAI chat model id clients request |
| **embed model id** | `miniLlmEmbedServedName = "local-embed"` | embeddings model id (router preset), `/v1/embeddings` on **8000** |
| **port** | `miniLlmPort = 8000` | chat + embeddings (router) |
| **bind** | `miniLlmHost = "0.0.0.0"` | tailnet bind |

**Router mode (two presets):** the llama.cpp backend runs **`llama-server` in router mode** (**`--models-preset <generated INI> --models-max 2`**), not a single-model server. The generated INI defines **two presets**; each preset's **section name is the OpenAI model id** served on **8000**:

- **`[local-chat]`** — **[unsloth/gemma-4-12B-it-qat-GGUF](https://huggingface.co/unsloth/gemma-4-12B-it-qat-GGUF)** at **`UD-Q4_K_XL`** with **vision** (`mmproj-auto`) **on**. **MTP** speculative decoding is **not configured** — the preset sets no `spec-type` / `spec-draft-n-max`; see **§ Change GGUF models / MTP tuning** below. The shared **`local-chat`** chat contract (`host.miniLlmServedName`), on port 8000. **Chat context is now 64K total** (`ctx-size = 65536`, `parallel = 2` → **32K per conversation**, `cache-type-k/v = q8_0`), **trimmed from the previous 96K** to leave room for the co-resident embedder.
- **`[local-embed]`** — **[mradermacher/F2LLM-v2-0.6B-GGUF](https://huggingface.co/mradermacher/F2LLM-v2-0.6B-GGUF)** at **`Q8_0`** (F2LLM-v2-0.6B, a Qwen3-architecture decoder embedding model, **1024-dim**, last-token pooling, **~0.6 GB**) with **`embedding = true`**, **`pooling = last`**, **`ctx-size = 8192`**. Served as the new id **`local-embed`** (`host.miniLlmEmbedServedName` in `hosts/mini/host.nix`), reachable at **`/v1/embeddings`**..

**`--models-max 2`** keeps **both** models **resident** (no swap latency); the embedder adds only **~0.6 GB**. If you would rather keep chat at maximum context, set **`--models-max 1`** (swap on demand — only the requested model is loaded at a time, at the cost of a load on each switch). Router/preset mechanics: section name = served model id; INI keys are long-form `llama-server` args minus `--`; presets use **`hf-repo`** so the router **auto-downloads** each model (and chat's sibling **`mmproj`**; the repo's **MTP** drafter is not fetched, since MTP is not configured). Local preset files allow the full arg set (the remote-HF security allowlist applies only to remote presets). Reference: llama.cpp `docs/preset.md` (PR#17859) + `tools/server/README.md`.

**llama.cpp chat model — QAT + vision (MTP not configured):** the **`local-chat`** preset serves **[unsloth/gemma-4-12B-it-qat-GGUF](https://huggingface.co/unsloth/gemma-4-12B-it-qat-GGUF)** at **`UD-Q4_K_XL`** — Google's **quantization-aware-trained** (QAT) Gemma 4 12B, and **`UD-Q4_K_XL`** (unsloth's dynamic 4-bit) is the **only** quant they ship for it (higher precisions degrade QAT accuracy, so there is nothing to "upgrade" to). At **~6.72 GB** of weights it delivers **near-bf16** quality. This **one repo bundles all three** pieces: the QAT weights, the **MTP** drafter (`mtp-gemma-4-12B-it.gguf` at the repo root), and the **`mmproj-*.gguf`** vision projector. First boot downloads **~10 GB** into **`/var/lib/llama-cpp/huggingface`** (plus the ~0.6 GB embedder) — though without MTP the ~2 GB drafter is **not** fetched/loaded.

**MTP** (Multi-Token Prediction) is **speculative decoding** worth roughly **1.5–2.2×** on generation, and the QAT repo bundles the drafter — but this backend **does not configure it**. There is no toggle: the preset simply omits `spec-type` / `spec-draft-n-max`, so the drafter is never fetched or loaded. The upstream blocker that originally justified leaving it out (the missing `gemma4-assistant` draft-arch loader) is **resolved** in our pinned llama.cpp; see **§ Change GGUF models / MTP tuning** for the two INI lines that turn it on and what to budget for.

Gemma 4's recommended sampling (**`--temp 1.0 --top-p 0.95 --top-k 64`**) is set as server defaults; clients override per request. On the 15 GiB Arc B50 the budget **without MTP** (current state) is chat **~9.7 GB** (QAT 6.7 + mmproj 1 + 64K q8 KV ~2) + embed ~0.6 GB ≈ **10.3 GB** — both fit resident with headroom (e.g. to raise `chatCtx`); **wiring up MTP** would add the **~2 GB** drafter on top. Vision stays on via **`mmproj-auto`** (the qat repo also ships `mmproj-*.gguf`).

**Shared module:** whichever backend is active, the stack aggregator **`hosts/mini/services/llm/default.nix`** is always imported when **`miniLlmHosting`** (`hosts/mini/default.nix` imports the single **`./services/llm`** folder, which resolves to it). It carries the shared base both backends need — the Intel GPU stack, the **`xe.force_probe`** kernel param, and the **`mini-llm-hf.env`** Hugging Face token sops template. (These previously lived inside `llm/llama-xpu.nix`.) `hosts/mini/services/llm/open-webui.nix` is always imported by it too.

**Chat (`8000`):** **`package = pkgs.llama-xpu-unstable.withTorchvision true`** because Qwen3.5's llama.cpp class imports Qwen VL image-processing code during inspection (now also genuinely needed — vision is enabled), **`quantization = null`** because llama.cpp's FP8 W8A8 path is not supported on Intel GPU/XPU, **`kvCacheDtype = null`** while stabilising boot, **`languageModelOnly = false`** (vision encoder profiling enabled — `Intel/Qwen3.5-9B-int4-AutoRound` is multimodal and its bf16 vision tower is retained, since AutoRound quantizes only `model.language_model.layers`), **`limitMmPerPrompt = { image = 1; video = 0; }`**, **`enforceEager = true`**, **`reasoningParser = qwen3`**. **`maxNumSeqs`** is lowered to **4** (from 8) to leave vision-encoder activation / image-embedding headroom on the ~15 GiB Arc Pro B50. If **`journalctl`** shows **`Available KV cache memory: X GiB`** with **X > 0**, raise **`maxModelLen`**. If **X < 0**, lower **`maxModelLen`**. Enabling vision on the XPU path is the **known-risky** scenario — if `llama-xpu-chat` fails to boot with images (chunk-prefill kernel / vision `profile_run` OOM / restart loop), consult **`docs/hosts/mini-llama-xpu.md`** § *Chunk prefill kernel not compiled / vision profile_run OOM*; text-only fallback is **`languageModelOnly = true`**. See [model card](https://huggingface.co/Qwen/Qwen3.5-9B).

Tune **`maxModelLen`** after a successful boot using **`Available KV cache memory`** in **`journalctl -u llama-xpu-chat`**. There is **no** llama.cpp **STT** instance in the default `llama-xpu.nix`; add **`instances.stt`** if you want **`8002`**.

**Other llama.cpp chat checkpoints:** Edit **`services.llama-xpu.instances.chat.*`** in `hosts/mini/services/llm/llama-xpu.nix` (e.g. Gemma 4 QAT, Gemma 3 GPTQ) — see **`docs/hosts/mini-llama-xpu.md`** for Gemma 4 **`gemma4_unified`** / Transformers pitfalls.

While **`miniBootstrap = true`** (first install), the flake skips the whole `./services/llm` folder (`llm/default.nix` and its shared base), `llama-xpu-nix`, `./llm/llama-xpu.nix`, and `./llm/llama-cpp.nix`. After §5.4 in `mini-install.md`, set **`miniBootstrap = false`**.

**`miniLlmHosting`** in `hosts/mini/host.nix` gates the whole chat stack. The **llama.cpp** backend additionally requires **`ca-derivations`** on the evaluating Nix (see `docs/hosts/mini-llama-xpu.md`); the **llama.cpp** backend does not.

## Default services on mini

| Service | Enabled | Notes |
|---------|---------|-------|
| `llama-cpp-gemma` | when `miniLlmHosting` | Router mode on **8000**: `local-chat` (Gemma 4 QAT + vision) + `local-embed` (F2LLM embeddings) |

## Clients and frontends

mini ships a **browser UI** ([Open WebUI](https://github.com/open-webui/open-webui), `hosts/mini/services/llm/open-webui.nix`) **and** the raw **OpenAI-compatible HTTP API**. Both are exposed on the **Tailscale tailnet** (`mini.quokka-qilin.ts.net`) and firewalled off the public internet — `modules/nixos/networking.nix` trusts only `tailscale0`, so the only public port is `:22`.

| What | URL |
|------|-----|
| **Web chat (Open WebUI)** | **`https://mini.quokka-qilin.ts.net`** — from any tailnet host's browser. HTTPS via `tailscale serve` (auto-renewed cert); first account created becomes admin |
| Chat / completions API | **`http://mini:8000/v1`** (tailnet) or **`http://127.0.0.1:8000/v1`** (on mini) — model id **`local-chat`** |
| Embeddings | **`http://mini:8000/v1/embeddings`** — model **`local-embed`** ([F2LLM-v2-0.6B](https://huggingface.co/mradermacher/F2LLM-v2-0.6B-GGUF), 1024-dim); router keeps it resident alongside `local-chat` |

**How it fits together:** llama-server binds **`0.0.0.0`** on **8000** (`miniLlmHost` / `miniLlmPort` from the shared contract) so other hosts can use the raw API directly — **no auth** on the chat server, but tailnet-only. Open-WebUI listens on **loopback `:8080`**; `tailscale serve` (the `tailscale-serve-open-webui` oneshot) terminates TLS at the MagicDNS name and proxies to it. **IDEs and agents** (Cursor, Continue, Aider, …) point their OpenAI base URL at `http://mini:8000/v1` from any tailnet host — no SSH tunnel needed. Open-WebUI also re-exports an OpenAI-compatible API at `https://mini.quokka-qilin.ts.net/api` gated by per-user keys, if you prefer authenticated access. The **§ SSH tunnels** below are now only needed from hosts **not** on the tailnet.

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

`deploy` uses `switch-fast` (no flake check / no commit on mini, since you authored upstream); run `deploy-dry` first if you want a pre-flight build. The `llama-xpu-kernels` rebuild caveat (`NIX_CONFIG='cores = 2'`, see `mini-llama-xpu.md`) still applies to the build that runs on mini.

### systemd — status, logs, control

The chat unit name depends on **`miniLlmHosting`**: **`llama-xpu-chat`** for `"llama"`, **`llama-cpp-gemma`** for `"llamacpp"`. Only the active backend's unit exists.

```bash
# List units for whichever backend is active
systemctl status llama-cpp-gemma
systemctl status llama-cpp-gemma            # llama.cpp backend
```

```bash
# llama.cpp backend
sudo systemctl status llama-cpp-gemma
# llama.cpp backend
sudo systemctl status llama-cpp-gemma

# Follow logs
sudo journalctl -fu llama-cpp-gemma

sudo journalctl -fu llama-cpp-gemma         # llama.cpp backend

sudo journalctl -u llama-cpp-gemma -e --no-pager
```

```bash
# Start / stop / restart (use the unit for your active backend)
sudo systemctl restart llama-cpp-gemma

sudo systemctl restart llama-cpp-gemma

sudo systemctl stop llama-cpp-gemma
sudo systemctl start llama-xpu-chat
```

```bash
# Disable / enable on boot (prefer changing Nix + `just switch` for durability)
sudo systemctl disable --now llama-cpp-gemma
sudo systemctl enable --now llama-cpp-gemma
```

### SSH — watch what llama.cpp is doing

**Interactive:** `ssh jadee@<mini-ip>`, then on mini use **`journalctl`** (below) and **`intel_gpu_top`** (installed on mini) to see logs vs GPU load.

**One-shot from your laptop** (no login shell — you get a stream until Ctrl+C):

```bash
ssh -t jadee@<mini-ip> 'sudo journalctl -fu llama-xpu-chat'
# second terminal for the embedder (starts after chat per unit ordering):

```

**GPU only** (whether llama.cpp is exercising the dGPU):

```bash
ssh -t jadee@<mini-ip> 'sudo intel_gpu_top'
```

llama.cpp’s OpenAI server does **not** expose a built-in “dashboard” over HTTP by default in this flake; **logs + GPU top** are the practical live views over SSH.

### APIs — list models

```bash
curl -s http://127.0.0.1:8000/v1/models | jq   # active chat backend — always advertises `local-chat`
#                                               # on the llama.cpp backend (router mode) this ALSO lists `local-embed`

```

Use the shared served id **`local-chat`** in all chat API calls — it is the same whether the active backend is llama.cpp or llama.cpp, so consumers never change when you switch backends. **`/v1/models`** also lists **`local-embed`**; use that id for **`/v1/embeddings`**.

### APIs — chat (`local-chat` on 8000)

For smoke tests, keep generation tiny and disable Qwen thinking. Long prompts with thinking enabled can look stuck on mini even while logs show low generation throughput. (Thinking-control flags below apply to the llama.cpp/Qwen backend; the llama.cpp/Gemma backend ignores them.)

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

### APIs — chat with image (both backends)

**Image input is ON by default on BOTH backends** with the existing chat models — **no repo swap needed**. The served id stays **`local-chat`** and images go in standard OpenAI **`image_url`** content parts (a public `https` image URL or a `data:` URL both work).

- **llama.cpp backend** (default): the SAME **`Intel/Qwen3.5-9B-int4-AutoRound`** serves images. It is natively multimodal (`Qwen3_5ForConditionalGeneration`, `image_token_id` set); AutoRound quantizes only `model.language_model.layers`, so the **bf16 vision tower is retained** in the int4 checkpoint. Config: **`languageModelOnly = false`**, **`limitMmPerPrompt = { image = 1; video = 0; }`**, **`maxNumSeqs = 4`** (see `hosts/mini/services/llm/llama-xpu.nix`). **Caveat:** enabling multimodal on the Intel **XPU** path is the known-risky scenario — on first boot with images llama.cpp's vision `profile_run` may request a chunk-prefill shape outside the compiled kernel set and fall back to a PyTorch path that OOMs the ~15 GiB GPU (restart loop). If image serving fails to boot, consult **`docs/hosts/mini-llama-xpu.md`** § *Chunk prefill kernel not compiled / EngineCore failed to start / XPU OOM during vision `profile_run`* (mitigations: a custom **`withKernelConfig`** kernel build with **`chunkPrefillExtra`**, and/or lowering **`maxModelLen`** / **`maxNumSeqs`**). Text-only fallback: **`languageModelOnly = true`**.
- **llama.cpp backend** (`miniLlmHosting = "llamacpp"`): the SAME **`unsloth/gemma-4-12B-it-qat-GGUF`** (`UD-Q4_K_XL` QAT, an `image-text-to-text` model) serves images. The repo ships **`mmproj-*.gguf`**; the **`-hf`** flag auto-downloads and loads it, and **`--mmproj-auto`** (in the `llama-server` args in `hosts/mini/services/llm/llama-cpp.nix`) makes that intent explicit (it is the default). The same repo also bundles the **MTP** drafter for speculative decoding, but **MTP is not configured** (see § *Change GGUF models / MTP tuning*), so the drafter is not loaded and only the projector matters here. The projector caches under `HF_HOME` alongside the weights. This Vulkan path is **reliable** — the low-risk way to get image input on mini. Text-only fallback: **`--no-mmproj`**.

```bash
# image input — model id stays `local-chat`, works on whichever backend is active.
# Run from a tailnet host (http://mini:8000) or on mini itself (http://127.0.0.1:8000).
curl -sS --max-time 600 http://mini:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "local-chat",
    "messages": [{
      "role": "user",
      "content": [
        {"type": "text", "text": "What'\''s in this image?"},
        {"type": "image_url", "image_url": {"url": "https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/beignets-task-guide.png"}}
      ]
    }],
    "max_tokens": 128,
    "stream": false,
    "chat_template_kwargs": {"enable_thinking": false}
  }' | jq .
```

A `data:` URL works too — replace the `url` value with e.g. `"data:image/png;base64,<BASE64>"`. The **`chat_template_kwargs: {"enable_thinking": false}`** line only applies to the **llama.cpp / Qwen** backend (it disables Qwen thinking); the **llama.cpp / Gemma** backend ignores it, so the same request body is byte-for-byte valid on either backend.

### APIs — chat (llama.cpp backend, `miniLlmHosting = "llamacpp"`)

When the llama.cpp backend is active it serves on the **same** port **8000** and the **same** served id **`local-chat`** — the request is byte-for-byte identical to the llama.cpp backend, so consumers do not change:

```bash
curl -s http://127.0.0.1:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "local-chat",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 64
  }' | jq
```

### APIs — embeddings (`local-embed` on 8000)

Embeddings are served by the **router**: the **`local-embed`** preset ([F2LLM-v2-0.6B](https://huggingface.co/mradermacher/F2LLM-v2-0.6B-GGUF) `Q8_0`, 1024-dim, last-token pooling) sits resident alongside **`local-chat`** on **8000** (`--models-max 2`) and answers at **`/v1/embeddings`**. 

```bash
# embeddings — llama.cpp backend (router mode), model id `local-embed`.
# Run from a tailnet host (http://mini:8000) or on mini itself (http://127.0.0.1:8000).
curl -sS --max-time 120 http://127.0.0.1:8000/v1/embeddings \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "local-embed",
    "input": "The quick brown fox jumps over the lazy dog."
  }' | jq '.data[0].embedding | length'   # -> 1024
```

> **llama.cpp backend (`:8001`, `jina-embeddings-v5-nano`):** that path is a separate concept and stays **disabled** so chat gets the full XPU memory budget. To restore it (llama.cpp backend only), set **`services.llama-xpu.instances.embedding.enable = true`** in `hosts/mini/services/llm/llama-xpu.nix` (with `miniLlmHosting = "llama"`), then switch. On mini today, the live embeddings endpoint is **`local-embed`** above, available whenever the llama.cpp backend is active.

### APIs — troubleshooting (no output, hangs, `jq`)

| Symptom | What to try |
|---------|-------------|
| **No output for a long time** | If logs show **`Running: 1 reqs`** and very low generation throughput, the request is alive but too slow. `just mini llm chat` waits up to **300s** for `/v1/models` before sending the smoke request; override with **`MINI_LLM_WAIT_SECONDS=<seconds>`**. First run **`just mini llm status`**, which prints the active backend's running command and flags any drift from the flake. If it has drifted, the host is not running this repo's config — `git add -A && just switch`, then restart the backend. For smoke tests use **`max_tokens: 8`** plus **`chat_template_kwargs: {"enable_thinking": false}`**. Stop the client with Ctrl-C; if the unit keeps generating, run **`just mini llm restart`**. |
| **`jq` prints nothing** | Do not pipe SSE streaming responses into `jq`; use raw/streaming output. For one complete JSON response, force **`"stream": false`** and wait for completion. |
| **HTTP / TLS errors** | Confirm **`/v1/models`** works first (§ list models), then inspect logs with **`just mini llm logs`**. |
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
# chat + (on the llama.cpp backend) embeddings both live on 8000;
# the 8001 forward is only for the llama.cpp `jina` embedder when that is enabled.
ssh -L 8000:127.0.0.1:8000 jadee@<mini-ip>
```

### GPU memory (shared Intel dGPU)

```bash
intel_gpu_top
```

## VRAM / coexistence

All services share the **same Intel GPU**. The two chat backends are **mutually exclusive** — **`miniLlmHosting`** picks exactly one, so **`llama-xpu-chat`** and **`llama-cpp-gemma`** are never imported together (running both would OOM the shared GPU). There is no longer an "additive optional llama.cpp" stack; switching backend means swapping which single chat unit owns the GPU.

The llama.cpp backend's Hugging Face cache lives under **`/var/lib/llama-cpp/huggingface`** when that backend is active.

**llama.cpp router co-residence (chat + embed):** the llama.cpp backend now hosts **two** models on the one GPU via **router mode** (`--models-max 2`, both resident — no swap latency). To make room for the embedder, **chat context was trimmed from 96K to 64K total** (`ctx-size = 65536`, `parallel = 2` → **32K per conversation**, `cache-type-k/v = q8_0`). Budget on the 15 GiB Arc B50 **without MTP** (current state): chat **~9.7 GB** (QAT 6.7 + mmproj 1 + 64K q8 KV ~2) + embed ~0.6 GB ≈ **10.3 GB**; **wiring up MTP** would add the **~2 GB** drafter. If you would rather keep chat at maximum context, set **`--models-max 1`** — only the requested model is loaded at a time (swap on demand), trading a per-switch load for headroom.

`llama-xpu-embedding` (the separate llama.cpp `jina-embeddings-v5-nano` instance) is currently disabled so chat can claim the full XPU memory
budget. If you re-enable it, order it after `llama-xpu-chat` and bind it to chat
so it cannot keep an XPU allocation while chat reloads the larger model. (On the **llama.cpp** backend you do not need it — embeddings come from the resident **`local-embed`** preset on **8000**.)

## Switching chat backend

One toggle in `hosts/mini/host.nix` selects the backend. Both serve **`local-chat`** on **8000** bound to **`0.0.0.0`** — consumers do not change.

| Goal | `hosts/mini/host.nix` | Per-backend tuning |
|------|------------------------|--------------------|
| **llama.cpp chat** (default) | `miniLlmHosting = "llama"` | `hosts/mini/services/llm/llama-xpu.nix`: `llama-chat-enable = true`, `models.chat.repo` / `instances.chat.*` as desired |
| **GGUF Gemma via llama.cpp** | `miniLlmHosting = true` | `hosts/mini/services/llm/llama-cpp.nix`: **router mode** (`--models-preset … --models-max 2`) serving **`local-chat`** = **`unsloth/gemma-4-12B-it-qat-GGUF`** `UD-Q4_K_XL` (QAT + vision, 64K ctx; **MTP** not configured) **and** **`local-embed`** = **`mradermacher/F2LLM-v2-0.6B-GGUF`** `Q8_0` (embeddings); tune `ctx-size`, `gpuLayers`, and **`--models-max`** (2 = both resident, 1 = swap on demand) as desired |

Then **`just switch`**. The shared contract (`miniLlmServedName` / `miniLlmPort` / `miniLlmHost`) is unchanged across the switch.

## Change GGUF models / MTP tuning (llama.cpp backend, router mode)

The llama.cpp backend runs **router mode** (`--models-preset <generated INI> --models-max 2`) with **two** presets — **`[local-chat]`** (Gemma 4 QAT + vision, **64K** ctx / **32K** per conversation; **no MTP**) and **`[local-embed]`** (F2LLM-v2-0.6B embeddings). Edit `hosts/mini/services/llm/llama-cpp.nix` (preset `ctx-size`, `gpuLayers`, and **`--models-max`** — 2 keeps both resident, 1 swaps on demand to keep chat at max context), ensure **`miniLlmHosting = "llamacpp"`**, then **`just switch`**. The served ids stay **`local-chat`** / **`local-embed`** (the INI section names = the served ids).

**Quant:** the QAT repo ships **only** **`UD-Q4_K_XL`** — that is intentional, since higher-precision quants degrade Google's quantization-aware-trained weights, so there is no higher-precision variant to move up to. At **~6.72 GB** it already gives near-bf16 quality.

**MTP — not wired (the former blocker is gone):** MTP (Multi-Token Prediction speculative decoding) would give roughly **1.5–2.2×** faster generation, and the QAT repo already bundles the drafter (`mtp-gemma-4-12B-it.gguf` at its root), but **nothing in `hosts/mini/services/llm/llama-cpp.nix` configures it** — no `spec-type`, no `spec-draft-n-max`, no drafter. There is no toggle to flip.

It was originally left out because llama.cpp shipped the `--spec-type draft-mtp` flag without the Gemma-specific **`gemma4-assistant`** draft-architecture loader, so loading the drafter died with `unknown model architecture: 'gemma4-assistant'` and took the server with it. **That blocker is resolved:** the arch landed in [ggml-org/llama.cpp#23398](https://github.com/ggml-org/llama.cpp/pull/23398) (merge `04eb4c4`, 2026-06-07), and our pinned nixpkgs ships llama.cpp **build 10133** (2026-07-26), which contains it — 584 commits past that merge.

**To actually enable it**, add to the `[local-chat]` preset in `hosts/mini/services/llm/llama-cpp.nix`:

```ini
spec-type = draft-mtp
spec-draft-n-max = 2
```

`hf-repo` auto-discovers the repo's root drafter (no `--model-draft` needed) and the drafter shares the target's KV cache. **`spec-draft-n-max`** is the tuning lever (range **1–6**, hardware-dependent; unsloth's QAT README uses 4, their general guidance is to start at 2). Budget for the extra **~2 GB** drafter first — see the VRAM figures above; then `just switch` and confirm the server comes up before trusting it, since a drafter failure kills the whole `local-chat` preset.

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

## Change llama.cpp chat model

Edit **`hosts/mini/services/llm/llama-xpu.nix`** (`models.chat.repo`, `instances.chat.*`), then **`just switch`**. Deep troubleshooting (KV OOM, ccache, kernel params) lives in **`docs/hosts/mini-llama-xpu.md`**.
