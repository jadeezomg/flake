# Mini — Intel XPU vLLM (vllm-xpu-nix)

This mirrors the **Brutus** host setup under `~/.dotfiles/examples/dotfiles`:

- Flake input [`vllm-xpu-nix`](https://github.com/jasonboukheir/vllm-xpu-nix) (NixOS module `services.vllm-xpu.*`).
- `hosts/mini/vllm-xpu.nix` — same kernel package / instance layout as `examples/dotfiles/hosts/brutus/services/vllm-xpu.nix`, without the examples repo’s `homelab.ports` (ports are fixed `8000` / `8001` / `8002`).

While **`miniBootstrap = true`** (first install), the flake skips `vllm-xpu-nix` and `./vllm-xpu.nix` so evaluators without `ca-derivations` still work. After §5.4 in `mini-install.md`, set **`miniBootstrap = false`**.

**`miniLlmHosting`** in `hosts/mini/host.nix` gates `vllm-xpu-nix`, `./vllm-xpu.nix`, optional `./llama-cpp.nix` (via **`miniLlamaCppGemma`**), and `dotfiles.profiles.devenv.llm.hosting` (`hosts/mini/profiles.nix`). Set **`true`** for Intel vLLM-XPU (requires **`ca-derivations`** on the evaluating Nix — see `modules/shared/environment.nix` and `lib/nix-experimental-features.nix` / Home Manager on Linux). Set **`false`** to drop the stack and skip CA-heavy evaluation.

## Hardware notes

- **`boot.kernelParams = ["xe.force_probe=e223"]`** matches Brutus (Intel Arc Battlemage–class dGPU). If mini has **only** integrated UHD and no discrete Arc card, remove that line or adjust the PCI ID after checking `lspci -nn`.
- **`intel-gpu-tools`** is installed for debugging (`intel_gpu_top`, etc.).
- **VRAM:** Chat is **[Qwen/Qwen3.6-35B-A3B-FP8](https://huggingface.co/Qwen/Qwen3.6-35B-A3B-FP8)** with **vision enabled** (`languageModelOnly = false`, **`limitMmPerPrompt`** for image/video caps). Tune **`maxModelLen`**, **`gpuMemoryUtilization`**, **`maxNumSeqs`**, and mm limits after **`journalctl -u vllm-xpu-chat`**. For **Gemma 4** again, see **§ Gemma 4 12B unified** and [vLLM recipe](https://recipes.vllm.ai/Google/gemma-4-12B-it) — **`gemma4_unified`** needs a new enough **Transformers** in **`vllm-xpu-nix`**.

## Operating models

Day-to-day **status, journalctl, curl, SSH tunnels, and start/stop** commands for vLLM + llama.cpp are in **`docs/hosts/mini-llm-hosting.md`** (single cheat sheet). After config changes on mini, use **`just switch`** (see `mini-install.md`).

Use **`servedName`** in requests (`qwen3.6-35b-a3b`, `jina-embeddings-v5-nano`), not necessarily the HF repo id.

## llama.cpp GGUF (optional)

**[unsloth/gemma-4-12b-it-GGUF](https://huggingface.co/unsloth/gemma-4-12b-it-GGUF)** can be served by **`llama-cpp-gemma`** on **8010** when **`miniLlamaCppGemma = true`** in `hosts/mini/host.nix` (`hosts/mini/llama-cpp.nix`). Default mini keeps it **off** while **`vllm-xpu-chat`** serves Qwen on **8000**. See **`docs/hosts/mini-llm-hosting.md`**.

With **`miniLlmHosting` true**, `./vllm-xpu.nix` **`mkForce`s `devenv.llm.hosting` off** so the generic devenv llama-cpp profile does not fight `./llama-cpp.nix`. With **`miniLlmHosting` false**, `profiles.nix` **`mkForce`s hosting off** too.

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
3. **Interim chat model:** **`ISTA-DASLab/gemma-3-12b-it-GPTQ-4b-128g`** with `servedName = "gemma-3-12b-it"` (see `hosts/mini/vllm-xpu.nix` comments) — **Gemma 3**, known to load on older stacks.
4. **Gemma 4 without vLLM on XPU:** enable **`miniLlamaCppGemma`** and serve **[unsloth GGUF](https://huggingface.co/unsloth/gemma-4-12b-it-GGUF)** via **`llama-cpp-gemma`** on **8010** (Vulkan path), at the cost of not using the vLLM OpenAI server on **8000** for that family.

### `UnicodeDecodeError` in `torch.library` / `_clear_torch_ops_cache`

Often appears **after** the `ModelConfig` / `ValidationError` traceback when the process tears down. Treat it as **noise** unless it is the **only** error: fix **Transformers / vLLM compatibility** first.

### `SYCL_HOME` / `intel-sycl-rt` warning

Torch XPU probing message during startup; unrelated to the Gemma 4 config validation failure unless compilation later fails for a different reason.

## Troubleshooting

### `ccache: error: Permission denied` (kernel builds, e.g. `attn-kernels-xe-2`)

`vllm-xpu-nix` wraps `icpx` with **ccache** and writes to `/var/cache/ccache`. The Nix build sandbox blocks that path unless the host exposes it.

`hosts/mini/vllm-xpu.nix` configures:

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

Weights loaded, but **KV cache init ran out of VRAM**. Common on mini when the Brutus-tuned stack (27B + MTP + 64k context + XPU graphs + co-resident embedding) exceeds the card.

**Quick test (no rebuild):**

```bash
sudo systemctl stop vllm-xpu-embedding
sudo systemctl restart vllm-xpu-chat
sudo journalctl -fu vllm-xpu-chat
```

**Tuning levers** (in `hosts/mini/vllm-xpu.nix` `instances.chat`):

| Knob | Effect |
|------|--------|
| Drop `speculativeConfig` (MTP) | Saves drafter + verify-pass VRAM |
| Lower `maxModelLen` (e.g. `32768` → `16384`) | Shrinks KV pool reservation |
| Lower `maxNumSeqs` | Less concurrent activation memory |
| Raise `gpuMemoryUtilization` (e.g. `0.92`) | More of total VRAM for vLLM |
| `enforceEager = true` / drop `enableXpuGraph` | Skips graph-capture buffers |
| Smaller chat model | Only fix if weights alone exceed VRAM |

Check GPU memory: `intel_gpu_top` (while the service starts).

### `warning: rejected … because shallow roots are not allowed to be updated`

This came from Nix’s **shallow** git fetch of `vllm-xpu-kernels-unstable-src` before widening to a full clone. The flake pins that input with **`shallow = false`** (see `flake.nix` under `vllm-xpu-nix.inputs`) so the fetch is non-shallow from the start.

### `error: store path '…-unit-….service.drv' does not exist` (often with `nix build --dry-run`)

Usually a **stale or partial store** after an interrupted fetch or a bad substituter pass, not a bug in your NixOS modules. Try a realisation pass without `--dry-run` (e.g. `nix build '.#nixosConfigurations.mini.config.system.build.toplevel' --no-link`), or verify the **whole** store with **`nix store verify --all --repair`** if you suspect corruption.

From this repo’s directory, **`nix store verify --repair` alone** fails: Nix treats the cwd as a flake and looks for `packages.<system>.default`, which this flake does not define. **`--all`** avoids that default installable and checks every store path.

### `options.json` / “without a proper context”

Harmless evaluator noise from options-doc / Home Manager manual generation (often louder on Determinate Nix). It does not block the mini build.

## Further reading

- **[Google/gemma-4-12B-it — vLLM Recipes](https://recipes.vllm.ai/Google/gemma-4-12B-it)** (nightly / CUDA Docker paths; compare to mini’s **XPU** stack in § Gemma 4 above).
- Long-form tuning notes and image/matrix experiments: `examples/dotfiles/docs/VLLM.md`.
