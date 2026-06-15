# Mini — Intel XPU vLLM (vllm-xpu-nix)

This mirrors the **Brutus** host setup under `~/.dotfiles/examples/dotfiles`, wired like upstream [Using on a NixOS server](https://github.com/jasonboukheir/vllm-xpu-nix/blob/main/docs/nixos-overlay.md):

- Flake input [`vllm-xpu-nix`](https://github.com/jasonboukheir/vllm-xpu-nix) with `inputs.nixpkgs.follows = "nixpkgs"` (see `flake.nix`).
- vLLM is **one of two interchangeable chat backends** on mini (the other is llama.cpp). It is the **default** backend, selected by **`miniLlmBackend = "vllm"`** in `hosts/mini/host.nix`. The shared serving contract (`miniLlmServedName = "local-chat"`, `miniLlmPort = 8000`, `miniLlmHost = "0.0.0.0"`) is the same no matter which backend is active — see **`docs/hosts/mini-llm-hosting.md`**.
- For **mini** with **`miniLlmHosting`** and the **vLLM** backend active, `hosts/mini/default.nix` adds **`inputs.vllm-xpu-nix.nixosModules.default`** (overlay + `services.vllm-xpu` options — same as the doc’s “import the NixOS module” step).
- **`hosts/mini/services/llm-base.nix`** (always imported when `miniLlmHosting`, shared by **both** backends) holds the **Intel graphics stack**, the **`xe.force_probe`** kernel param, and the **sops** Hugging Face token template (**`mini-llm-hf.env`**). These previously lived inside `vllm-xpu.nix`.
- `hosts/mini/services/vllm-xpu.nix` — the vLLM-specific **`services.vllm-xpu`** instance block plus **ccache** sandbox paths. Chat uses **`pkgs.vllm-xpu-unstable.withTorchvision true`** and serves on the shared **port 8000** as **`local-chat`**. Embedding is defined but disabled so chat gets the full XPU memory budget.

> **Note:** the `miniBootstrap` toggle was removed after mini was bootstrapped — the stack is now gated only by `miniLlmHosting`. For a fresh reinstall, re-introduce a bootstrap exception (see `mini-install.md` §4.4/§5.5).

**`miniLlmHosting`** in `hosts/mini/host.nix` gates the whole chat stack: it always imports `./llm-base.nix` + `./open-webui.nix`, then — driven by **`miniLlmBackend`** — either `vllm-xpu-nix` + `./vllm-xpu.nix` (`"vllm"`) **or** `./llama-cpp.nix` (`"llamacpp"`). The **vLLM** backend requires **`ca-derivations`** on the evaluating Nix (see `modules/shared/environment.nix` and `lib/nix-experimental-features.nix` / Home Manager on Linux); the llama.cpp backend does not. Set `miniLlmHosting = false` to drop the stack entirely and skip CA-heavy evaluation.

## Hardware notes

- **`boot.kernelParams = ["xe.force_probe=e223"]`** matches Brutus (Intel Arc Battlemage–class dGPU). If mini has **only** integrated UHD and no discrete Arc card, remove that line or adjust the PCI ID after checking `lspci -nn`.
- **`intel-gpu-tools`** is installed for debugging (`intel_gpu_top`, etc.).
- **VRAM / context:** mini's GPU is an **Intel Arc Pro B50** with only **~15 GiB**. Unquantized **Qwen3.5-9B** (bf16 **~18 GiB** of weights) does **not** fit — it fails vLLM's startup memory pre-check (`Free memory on device xpu:0 … less than desired GPU memory utilization`) regardless of `gpuMemoryUtilization`, and lowering that knob only moves the failure to an OOM during weight load. Chat therefore runs **[Intel/Qwen3.5-9B-int4-AutoRound](https://huggingface.co/Intel/Qwen3.5-9B-int4-AutoRound)** (int4 AutoRound, **~5 GiB** weights — same pattern as the reference brutus `Intel/…-int4-AutoRound`). It packs as `auto_round:auto_gptq`, so it loads via **`quantization = "gptq"`**. Other settings: **`pkgs.vllm-xpu-unstable.withTorchvision true`** (Qwen3.5 imports Qwen VL image-processing code during vLLM inspection), **`languageModelOnly = true`**, **`enforceEager = true`**, pinned **`--revision`**. Embedding is disabled so chat gets the whole budget.

  Qwen3.5 is a **hybrid linear-attention** model: only **8 of 32** layers are full attention (`full_attention_interval = 4`); the rest keep a fixed-size recurrent state that does **not** grow with context. With 4 GQA KV heads × 256 head-dim that is just **16 KiB/token at fp8** (32 KiB bf16), so KV is cheap and context is **not** the constraint here. With **`kvCacheDtype = "fp8"`** the model's full **262,144** context costs only **~4 GiB** of KV. Current config: **`kvCacheDtype = "fp8"`**, **`maxModelLen = 131072`** (128k; raise toward 262144 once vLLM's reported `GPU KV cache size` confirms room), **`gpuMemoryUtilization = 0.9`**. The B50 is **headless** (display runs on the Iris Xe iGPU), so vLLM can claim more of the card than the reference's 0.85 — but **0.95** failed the startup free-memory pre-check (needed 15.13 of 15.01 GiB free), so 0.90 is the safe ceiling. The ~1.5 GiB runtime overhead is vLLM's Level-Zero/oneCCL context + activation peak, **not** a desktop compositor, so headless does not reduce it. If fp8 KV destabilises boot (see the FP8 troubleshooting note below), fall back to **`kvCacheDtype = null`** (bf16 KV still fits ~120k tokens). For **image/video**, switch to a **VL** repo and set **`languageModelOnly = false`** + **`limitMmPerPrompt`**.

## Operating models

Day-to-day **status, journalctl, curl, SSH tunnels, and start/stop** commands for both backends are in **`docs/hosts/mini-llm-hosting.md`** (single cheat sheet). After config changes on mini, use **`just switch`** (see `mini-install.md`).

Use the shared served id **`local-chat`** in chat requests (and **`jina-embeddings-v5-nano`** for embeddings when re-enabled), not the HF repo id. The chat id is the same across backends.

## llama.cpp GGUF (the other backend)

**[unsloth/gemma-4-12b-it-GGUF](https://huggingface.co/unsloth/gemma-4-12b-it-GGUF)** is served by **`llama-cpp-gemma`** on the shared **port 8000** (as **`local-chat`**) when **`miniLlmBackend = "llamacpp"`** in `hosts/mini/host.nix` (`hosts/mini/services/llama-cpp.nix`). It is the **mutually-exclusive alternative** to the default vLLM backend — selecting it stops vLLM from being imported, since both would OOM the shared GPU. See **`docs/hosts/mini-llm-hosting.md`**.

The generic serving stack (`dotfiles.profiles.llm`) defaults off and stays off on mini — `./vllm-xpu.nix` / `./llama-cpp.nix` own LLM serving here.

## Gemma 4 12B unified (recipe vs Intel XPU)

Upstream guide: **[Google/gemma-4-12B-it — vLLM Recipes](https://recipes.vllm.ai/Google/gemma-4-12B-it)**.

Important context from that page:

- **Encoder-free 12B unified** support landed in upstream vLLM behind work that the recipe labels as **“nightly required”** (not only the Docker tag — the doc points at a **pinned `vllm/vllm-openai:gemma4-unified`** image and **nightly pip** flows for CUDA). Mini uses **`vllm-xpu-nix`** (Intel **XPU**), which tracks upstream on its own schedule: **recipe commands do not transfer 1:1**, but the **version / Transformers** requirements are the same class of problem.
- The recipe’s **quick start** uses **`google/gemma-4-12B-it`** (BF16, large VRAM — the page targets **40 GB+** class GPUs for that path). The **QAT compressed-tensors** repo (**`google/gemma-4-12B-it-qat-w4a16-ct`**) is a different checkpoint but the same **`gemma4_unified`** / **`Gemma4UnifiedForConditionalGeneration`** family: if **Transformers** in your closure does not register that architecture, **switching BF16 vs QAT will not fix** `ModelConfig` validation — you need a **newer `transformers` + vLLM** as bundled by **`vllm-xpu-nix`** (bump the flake input / follow that repo’s releases).

### `model type gemma4_unified but Transformers does not recognize this architecture`

This is the **real blocker**: the **`google/gemma-4-12B-it-qat-w4a16-ct`** (and BF16 **`google/gemma-4-12B-it`**) config advertises **`gemma4_unified`**, but the **`transformers`** pinned inside your **`python3.12-vllm-xpu-…`** build is **too old** to expose that model type to vLLM’s `ModelConfig`.

**What to do (in order):**

1. **Bump `inputs.vllm-xpu-nix`** (and let it pull newer `vllm-xpu-unstable` / `transformers`) until `nixos-rebuild` / `just switch` gets a vLLM that loads Gemma 4 — watch [vllm-xpu-nix](https://github.com/jasonboukheir/vllm-xpu-nix) and upstream [vllm](https://github.com/vllm-project/vllm) / recipe PR references.
2. **Optional VRAM experiment (only after (1)):** set `models.chat.repo` to **`google/gemma-4-12B-it`** to mirror the recipe’s BF16 quick start — still requires a build that **recognizes** `gemma4_unified`; expect **much higher** memory than QAT CT.
3. **Interim chat model:** **`ISTA-DASLab/gemma-3-12b-it-GPTQ-4b-128g`** as **`models.chat.repo`** in **`hosts/mini/services/vllm-xpu.nix`** — **Gemma 3**, known to load on older stacks. (It is still advertised as **`local-chat`** — the served id is the shared contract, independent of the underlying repo.)
4. **Gemma 4 without vLLM on XPU:** switch to the llama.cpp backend (**`miniLlmBackend = "llamacpp"`**) to serve **[unsloth GGUF](https://huggingface.co/unsloth/gemma-4-12b-it-GGUF)** via **`llama-cpp-gemma`** on the shared **port 8000** (Vulkan path). This is a backend swap, not an additional server — vLLM is no longer imported while llama.cpp is the active backend.

### `UnicodeDecodeError` in `torch.library` / `_clear_torch_ops_cache`

Often appears **after** the `ModelConfig` / `ValidationError` traceback when the process tears down. Treat it as **noise** unless it is the **only** error: fix **Transformers / vLLM compatibility** first.

### `SYCL_HOME` / `intel-sycl-rt` warning

Torch XPU probing message during startup; unrelated to the Gemma 4 config validation failure unless compilation later fails for a different reason.

## Troubleshooting

### `ccache: error: Permission denied` (kernel builds, e.g. `attn-kernels-xe-2`)

`vllm-xpu-nix` wraps `icpx` with **ccache** and writes to `/var/cache/ccache`. The Nix build sandbox blocks that path unless the host exposes it.

`hosts/mini/services/vllm-xpu.nix` configures:

- `systemd.tmpfiles.rules` — create `/var/cache/ccache` (`0770`, group `nixbld`)
- `nix.settings.extra-sandbox-paths` — let sandboxed builds write the cache

**Before the first switch that includes this config**, bootstrap the directory and pass the sandbox path once (chicken-and-egg: the option is in the closure you are building):

```bash
sudo install -d -m 0770 -o root -g nixbld /var/cache/ccache
sudo nixos-rebuild switch --flake ~/.dotfiles/flake#mini --option extra-sandbox-paths /var/cache/ccache
```

After switch, later rebuilds pick up `extra-sandbox-paths` from `/etc/nix/nix.conf` automatically.

To skip ccache for a one-off package build (CI / no cache dir):

```bash
nix build 'github:jasonboukheir/vllm-xpu-nix#attn-kernels-xe-2.withCcache false'
```

Inspect cache use: `ccache --show-stats --dir /var/cache/ccache`

### `Available KV cache memory: -X GiB` / `No available memory for the cache blocks`

Weights loaded, but **KV cache init ran out of VRAM**. Common on mini when the context window is too large or another GPU service is co-resident.

Embedding is disabled by default while tuning chat. If you re-enable it later, first isolate chat with:

```bash
sudo systemctl stop vllm-xpu-embedding
sudo systemctl restart vllm-xpu-chat
sudo journalctl -fu vllm-xpu-chat
```

**Tuning levers** (in `hosts/mini/services/vllm-xpu.nix` `instances.chat`):

| Knob | Effect |
|------|--------|
| **`quantization = null`** (default on mini chat) | Avoids vLLM FP8 W8A8 weight quantization, which is unsupported on Intel GPU/XPU |
| **`kvCacheDtype = null`** while stabilising boot | Avoids the quantized KV path until the model starts reliably |
| **`languageModelOnly = true`** | Skips vision encoder cache / multimodal startup on Qwen3.5 |
| **`enforceEager = true`** | Skips XPU graph capture buffers |
| Raise `maxModelLen` (default **8192**) | Larger context cap when **`Available KV cache memory` > 0** |
| Lower `maxModelLen` | Shrinks KV pool if startup reports negative KV memory |
| Lower `maxNumSeqs` (default **1**) | More KV budget per active conversation |
| Raise `gpuMemoryUtilization` (default **0.85**) | More of total VRAM for vLLM (the **0.95** pre-check failure showed too little headroom on the B50) |
| Keep `instances.embedding.enable = false` | Gives chat the whole XPU memory budget |
| Smaller or supported quantized chat model | Only fix if unquantized weights alone exceed VRAM |

Check GPU memory: `intel_gpu_top` (while the service starts).

### `EngineCore failed to start` right after XCCL init with FP8 enabled

**Cause:** The crash has occurred with both **`quantization = "fp8"`** and later with **`kvCacheDtype = "fp8"`** in the mini setup. vLLM's FP8 W8A8 weight quantization is not supported on Intel GPU/XPU in the upstream hardware matrix; the KV path may also hit XPU backend bugs before weight loading.

**Fix:** keep both **`quantization = null`** and **`kvCacheDtype = null`** while stabilising Qwen3.5 on mini. Re-enable **only one** FP8 path after a clean boot, starting with KV cache and checking full logs.

### `ModuleNotFoundError: No module named 'torchvision'` during Qwen3.5 inspection

**Cause:** vLLM imports `vllm.model_executor.models.qwen3_5`, which imports `qwen3_vl`; Transformers then imports `torchvision.transforms.v2` even when mini serves text-only Qwen3.5 with **`languageModelOnly = true`**. The service fails before binding **`:8000`**.

**Fix:** keep chat on **`pkgs.vllm-xpu-unstable.withTorchvision true`**. This only adds the XPU torchvision wheel to the vLLM Python closure; it does not enable multimodal profiling while **`languageModelOnly = true`**.

### `Chunk prefill kernel not compiled` / `EngineCore failed to start` / XPU OOM during vision `profile_run`

Symptoms: **`Chunk prefill kernel not compiled for this configuration`**, suggestion to add **`96,false,false,false,false,false`** to **`chunk_prefill_default`**, then **`RuntimeError`** / **`torch.OutOfMemoryError`** (often huge “tried to allocate … GiB”) during **`embed_multimodal`** / vision encoder profiling — **`vllm-xpu-chat`** enters a **restart loop**.

**Cause:** **`vllm-xpu-kernels`** ships a **fixed set** of chunk-prefill shapes. With the **default** `pkgs.vllm-xpu-unstable` package (no custom **`withKernelConfig`**), **multimodal** (e.g. **Qwen3-VL**) startup profiling can request a shape **not** in that set, so vLLM **falls back** to a PyTorch attention path that can **explode memory** on a **~16 GiB** dGPU.

**Fix (optional custom kernel build):** set **`services.vllm-xpu.package`** to **`(pkgs.vllm-xpu-unstable.withTorchvision true).withKernelConfig { ... }`** and add **`chunkPrefillExtra`** entries (historically **`"96,false,false,false,false,false"`** for Qwen3.6 VL — see past revisions of `hosts/mini/services/vllm-xpu.nix` or [vllm-xpu-kernels#364](https://github.com/vllm-project/vllm-xpu-kernels/issues/364)). After **`withKernelConfig`**, **`just switch`** **rebuilds** the XPU kernel package (can take a long time; needs **`/var/cache/ccache`** per § ccache above).

If it **still** OOMs: temporarily **`sudo systemctl stop vllm-xpu-embedding`**, lower **`maxModelLen`** / **`maxNumSeqs`**, or set **`languageModelOnly = true`** to drop multimodal serving until VRAM fits. Upstream context: [vllm-xpu-kernels#364](https://github.com/vllm-project/vllm-xpu-kernels/issues/364).

### `ptr_scales of fp8 must be 1D [num_experts]` (after weights load / `torch.compile`)

Symptoms: **`EngineCore failed to start`** during **`profile_run`** / **`_dummy_run`**, stack through **`xpu_moe.py`** / **`cutlass_grouped_gemm_interface`** / **`fused_moe_interface`**, ending in **`RuntimeError: ptr_scales of fp8 must be 1D [num_experts]`**.

**Cause:** The **native XPU** FP8 grouped-GEMM MoE path expects **per-expert scale tensors** in a layout some **FP8 MoE** checkpoints (e.g. **Qwen3.6-35B-A3B-FP8**) do not provide (or vLLM reshapes them differently after **`torch.compile`**).

**Fix:** For **MoE FP8** on XPU, add **`--moe-backend triton`** to **`instances.chat.extraArgs`** so FP8 MoE uses the **Triton** expert path (slower than a tuned native kernel, but clears startup). The default mini chat (**Qwen3.5-9B**, dense text) does **not** need this.

If **`triton`** is rejected by your **`vllm-xpu`** build, try **`enforceEager = true`** and **`enableXpuGraph = false`** in `vllm-xpu.nix`, or **bump `vllm-xpu-nix`**.

### `warning: rejected … because shallow roots are not allowed to be updated`

This came from Nix’s **shallow** git fetch of `vllm-xpu-kernels-unstable-src` before widening to a full clone. The flake pins that input with **`shallow = false`** (see `flake.nix` under `vllm-xpu-nix.inputs`) so the fetch is non-shallow from the start.

### `error: store path '…-unit-….service.drv' does not exist` (often with `nix build --dry-run`)

Usually a **stale or partial store** after an interrupted fetch or a bad substituter pass, not a bug in your NixOS modules. Try a realisation pass without `--dry-run` (e.g. `nix build '.#nixosConfigurations.mini.config.system.build.toplevel' --no-link`), or verify the **whole** store with **`nix store verify --all --repair`** if you suspect corruption.

From this repo’s directory, **`nix store verify --repair` alone** fails: Nix treats the cwd as a flake and looks for `packages.<system>.default`, which this flake does not define. **`--all`** avoids that default installable and checks every store path.

### `options.json` / “without a proper context”

Harmless evaluator noise from options-doc / Home Manager manual generation (often louder on Determinate Nix). It does not block the mini build.

### `icpx: error: unable to execute command: Killed` while building `attn-kernels-xe-2`

This is a host RAM OOM during local XPU kernel compilation, not a vLLM runtime
error. Upstream notes the worst translation units are about **7 GiB RSS** and
`ninja` runs at **`-j$NIX_BUILD_CORES`**. On mini's 24 GiB RAM, `buildCores = 4`
can launch enough `icpx` jobs to OOM-kill one compiler process.

`hosts/mini/host.nix` caps **`buildCores = 2`** for steady state. If the failing
build is the **first** switch that lowers that setting, the current Nix daemon may
still be using the old core count. Bootstrap that one build with an explicit cap:

```bash
NIX_CONFIG='cores = 2' just switch-fast
```

If you build the derivation directly, use upstream's equivalent one-shot flag:

```bash
nix build --cores 2 '.#nixosConfigurations.mini.config.system.build.toplevel'
```

The repeated `nix-output-monitor error: DerivationParseError "string"` lines are
secondary log-parser noise; the root failure is the killed `icpx` process.

## Further reading

- **[Google/gemma-4-12B-it — vLLM Recipes](https://recipes.vllm.ai/Google/gemma-4-12B-it)** (nightly / CUDA Docker paths; compare to mini’s **XPU** stack in § Gemma 4 above).
- Long-form tuning notes and image/matrix experiments: `examples/dotfiles/docs/VLLM.md`.
