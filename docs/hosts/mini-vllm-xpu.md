# Mini — Intel XPU vLLM (vllm-xpu-nix)

This mirrors the **Brutus** host setup under `~/.dotfiles/examples/dotfiles`:

- Flake input [`vllm-xpu-nix`](https://github.com/jasonboukheir/vllm-xpu-nix) (NixOS module `services.vllm-xpu.*`).
- `hosts/mini/vllm-xpu.nix` — same kernel package / instance layout as `examples/dotfiles/hosts/brutus/services/vllm-xpu.nix`, without the examples repo’s `homelab.ports` (ports are fixed `8000` / `8001` / `8002`).

While **`miniBootstrap = true`** (first install), the flake skips `vllm-xpu-nix` and `./vllm-xpu.nix` so evaluators without `ca-derivations` still work. After §5.4 in `mini-install.md`, set **`miniBootstrap = false`**.

**`miniLlmHosting`** in `hosts/mini/host.nix` gates `vllm-xpu-nix`, `./vllm-xpu.nix`, `./llama-cpp.nix`, and `dotfiles.profiles.devenv.llm.hosting` (`hosts/mini/profiles.nix`). Set **`true`** for Intel vLLM-XPU + llama.cpp GGUF (requires **`ca-derivations`** on the evaluating Nix — see `modules/shared/environment.nix` and `lib/nix-experimental-features.nix` / Home Manager on Linux). Set **`false`** to drop both stacks and skip CA-heavy evaluation.

## Hardware notes

- **`boot.kernelParams = ["xe.force_probe=e223"]`** matches Brutus (Intel Arc Battlemage–class dGPU). If mini has **only** integrated UHD and no discrete Arc card, remove that line or adjust the PCI ID after checking `lspci -nn`.
- **`intel-gpu-tools`** is installed for debugging (`intel_gpu_top`, etc.).
- **VRAM:** `Qwen3.6-27B-int4` needs **~17 GiB** for weights alone. Brutus tunes for a **32 GiB** Arc Pro B70; mini's card may be smaller — `hosts/mini/vllm-xpu.nix` uses a tighter chat profile (no MTP, 32k ctx, higher `gpuMemoryUtilization`) than the Brutus copy.

## Operating models

After `nixos-rebuild switch`:

```bash
sudo systemctl status vllm-xpu-chat vllm-xpu-embedding
sudo journalctl -fu vllm-xpu-chat   # first start: HF download + compile can take a while
curl -s http://127.0.0.1:8000/v1/models | jq
```

APIs bind **`127.0.0.1` only** (ports `8000` chat, `8001` embeddings). From another machine: `ssh -L 8000:127.0.0.1:8000 -L 8001:127.0.0.1:8001 jadee@<mini-ip>`.

Use **`servedName`** in requests (`qwen3.6-27b`, `jina-embeddings-v5-nano`), not necessarily the HF repo id.

## llama.cpp GGUF (additive)

**[unsloth/gemma-4-12b-it-GGUF](https://huggingface.co/unsloth/gemma-4-12b-it-GGUF)** is served by **`llama-cpp-gemma`** on port **8010** (`hosts/mini/llama-cpp.nix`). This is **in addition to** vLLM-XPU, not a replacement. See **`docs/hosts/mini-llm-hosting.md`** for the combined port map and VRAM notes.

With **`miniLlmHosting` true**, `./vllm-xpu.nix` **`mkForce`s `devenv.llm.hosting` off** so the generic devenv llama-cpp profile does not fight `./llama-cpp.nix`. With **`miniLlmHosting` false**, `profiles.nix` **`mkForce`s hosting off** too.

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

Long-form tuning notes and image/matrix experiments live in the examples tree: `examples/dotfiles/docs/VLLM.md`.
