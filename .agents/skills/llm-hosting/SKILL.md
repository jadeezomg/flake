---
name: llm-hosting
description: Change local LLM serving (llama.cpp router models, context, embeddings) or the LLM toolbox. Use when editing modules/profiles/llm/**, hosts/mini/services/llm/**, tuning the served chat/embedding models, context/KV/slots, MTP, or the `just mini llm` ops, or when the local LLM fails to load/serve.
---

# LLM Hosting

## Scope

The `dotfiles.profiles.llm` profile has two toggles. Options are declared in `modules/profiles/default.nix` (the `llm` block). Reference doc: `docs/hosts/mini.md` § 6 LLM stack.

- `llm.tools.enable`: llama.cpp CLI, `hf` CLI (`huggingface-hub`), and the `unsloth-studio` podman user service (`modules/profiles/llm/unsloth.nix`). Darwin gets podman only. On: desktop.
- `llm.serve.enable`: the llama.cpp router server, one `llama-cpp` systemd unit (`modules/profiles/llm/serve.nix`). Linux only. On: mini, through `host.miniLlmHosting` in `hosts/mini/host.nix`, which imports `hosts/mini/services/llm/`.

## llama-cpp build

`modules/profiles/llm/default.nix` derives the backend from `dotfiles.hardware.gpu`: `nvidia` -> CUDA, `intel` and `amd` -> Vulkan, `none` -> CPU. `llm.llamaCppBackend` (`"cpu"`, `"vulkan"`, `"cuda"`) overrides it. `llm.llamaCppPackage` holds the result; override it to pin a build. nixpkgs does not build SYCL or OpenVINO. The GPU userspace (Intel compute runtime, media driver, `intel-gpu-tools`) comes from the hardware trait `modules/profiles/hardware/gpu-*.nix`, not from this profile.

## Serve options (`llm.serve`)

- `host` (default `127.0.0.1`), `port` (default `8000`). mini binds `0.0.0.0`; the firewall trusts only `tailscale0`, so the port is tailnet-only.
- `threads` (`--threads`, `null` = server default). `modelsMax` (`--models-max`, `null` = all models resident). `gpuLayers` (default `999`, all layers).
- `device` sets `LLAMA_ARG_DEVICE` (`null` = auto). List ids with `llama-server --list-devices`. No-rebuild escape hatch: `sudo systemctl edit llama-cpp` and add `Environment=LLAMA_ARG_DEVICE=...`.
- `stateDir` (default `/var/lib/llama-cpp`). Models download into `<stateDir>/huggingface`.
- `environmentFile`: the unit's `EnvironmentFile`. mini passes the sops template `mini-llm-hf.env` (`HF_TOKEN`), declared in `hosts/mini/secrets.nix`.
- `models.<id>`: one INI section per served model. `<id>` is the OpenAI model id. Fields: `hfRepo`, `quant` (rendered as `repo:quant`), `ctx` (TOTAL pool, split across `slots`), `slots` (`parallel`), `kvType` (`cache-type-k`/`-v`), `embedding`, `pooling`, `mmprojAuto`, `flashAttn` (`on`/`off`/`auto`), and `settings` for any other long-form `llama-server` arg without `--`. Write floats as strings (`temp = "1.0"`).

The module renders the INI, the `llama` system user, tmpfiles, and the unit. Do not add a second llama-server unit on a host; add a model instead.

## mini (`hosts/mini/services/llm/`)

- `default.nix`: enables `llm.serve` with mini's values and imports `open-webui.nix`. Edit the model knobs here, not raw args.
- `open-webui.nix`: Open WebUI on loopback `127.0.0.1:8080`. Caddy serves it at `chat.jadee.fyi`. It reads the port from `llm.serve.port` and talks to `http://127.0.0.1:8000/v1` with `OPENAI_API_KEY = "sk-no-auth"` (the server has no auth). `ENABLE_OLLAMA_API = "False"`.

Current presets (`--models-max 2`, both resident; `1` swaps on demand and gives chat the full VRAM):

- `local-chat`: `unsloth/gemma-4-12B-it-qat-GGUF` `UD-Q4_K_XL`. This is the only quant in the QAT repo. Higher precision degrades QAT weights, so there is nothing to upgrade to. `ctx = 131072`, `slots = 2`, so 64K per conversation. `kvType = "q8_0"` needs `flashAttn = "on"`; if Vulkan refuses, use `"f16"`. Vision is on (`mmprojAuto`). Sampling in `settings`: `temp = "1.0"`, `top-p = "0.95"`, `top-k = 64`, plus `jinja = true`.
- `local-embed`: `mradermacher/F2LLM-v2-0.6B-GGUF` `Q8_0`, `embedding = true`, `pooling = "last"` (Qwen3-arch embedders), `ctx = 8192`.

**MTP (speculative decoding)** is not configured. The old blocker (missing `gemma4-assistant` draft arch) is resolved in the pinned llama.cpp. To enable it, add `spec-type = "draft-mtp"` and `spec-draft-n-max = 2` (range 1 to 6) to `models.local-chat.settings`. `hf-repo` finds the bundled drafter. Budget about +2 GB of VRAM. Make sure that the server comes up, because a drafter failure kills the whole preset.

## VRAM budget (15 GiB Arc B50)

QAT ~6.7 + mmproj ~1 + embedder ~0.6 + overhead ~1.5 ≈ 9.8 GB. About 5.2 GB remain for chat KV. Gemma 4 is cheap on KV (8 of 48 layers are full-attention, the rest cap at a 1024 sliding window), about 32 KiB/token at q8_0. 128K ≈ 4.2 GB, with about 1 GB margin. The true maximum is empirical. `journalctl -u llama-cpp` prints the KV size on load. `intel_gpu_top` shows VRAM. The comments in `hosts/mini/services/llm/default.nix` carry the current math.

## Apply

Author changes locally. Never edit over SSH on mini.

1. `git add -A` (flakes only see tracked files).
2. `flake fmt` after `.nix` edits.
3. Eval-check the unit: `nix eval --raw .#nixosConfigurations.mini.config.systemd.services.llama-cpp.serviceConfig.ExecStart`.
4. Commit and push. `deploy` pulls `origin/main` on mini.
5. `just mini deploy` (pull, then `switch-fast`). Siblings: `just mini deploy-dry` (build only), `just mini deploy-boot` (stage for reboot).

The first boot downloads about 10 GB into `/var/lib/llama-cpp/huggingface`.

## Ops (`just mini llm <cmd>`)

`overview`, `status`, `logs`, `restart`, `models`, `chat [prompt]`, `perf`, `embedding [text]`, `gpu`, `troubleshoot`, `bench`. Script: `scripts/shell/mini-llm.bash` (targets the `llama-cpp` unit).

`just mini llm status` is the first diagnostic. It prints the running `ExecStart` and flags drift from the flake output. Drift means the switch did not apply, or systemd runs a stale unit. Deploy again, then `restart`.

`bench` (llama-benchy) runs from any host. Keep `MINI_BENCH_CONCURRENCY` (default `1 2` in `just/mini-llm.just`) in sync with `models.local-chat.slots`. Requests past the slot count only measure queueing.
