---
name: llm-hosting
description: Change mini's local LLM serving (llama.cpp models, context, embeddings). Use when editing hosts/mini/services/llm/**, tuning the served chat/embedding models, context/KV/slots, MTP, or the `just mini llm` ops, or when the local LLM fails to load/serve.
---

# LLM Hosting (mini)

## Scope

Local LLM serving on the **mini** host. The code lives under `hosts/mini/services/llm/`. The contract facts live in `hosts/mini/host.nix`. The knob `miniLlmHosting` gates the whole stack. Reference doc: `docs/hosts/mini.md` § 6 LLM stack.

## The contract (`hosts/mini/host.nix`)

- `miniLlmServedName` = `"local-chat"`, the OpenAI chat model id.
- `miniLlmEmbedServedName` = `"local-embed"`, the embeddings id on the same port.
- `miniLlmPort` = `8000`. `miniLlmHost` = `"0.0.0.0"`. The firewall trusts only `tailscale0`, so the port is tailnet-only.
- `miniLlamaCppGgmlBackends` = `"vulkan"` or `"vulkan-opencl"`. nixpkgs `llama-cpp` builds Vulkan and OpenCL only, not SYCL or OpenVINO.
- `miniLlamaCppDevice` sets `LLAMA_ARG_DEVICE` (`null` = auto). List ids with `llama-server --list-devices`.

No-rebuild escape hatch for the device: `sudo systemctl edit llama-cpp-gemma` and add `Environment=LLAMA_ARG_DEVICE=...`.

## Files

- `default.nix`: aggregator and shared base. It imports `open-webui.nix`, `llama-cpp.nix`, and `modules/profiles/llm/hosting-tools.nix` (`huggingface-hub` CLI). It sets `hardware.graphics.extraPackages` (Intel compute runtime, media driver, `vpl-gpu-rt`), adds `intel-gpu-tools`, and sets `boot.kernelParams` `xe.force_probe=e223`. It also renders the HF token into `mini-llm-hf.env` from sops `hf_token`.
- `llama-cpp.nix`: the `llama-cpp-gemma` unit (router mode, see below).
- `open-webui.nix`: Open WebUI on loopback `127.0.0.1:8080`. Caddy serves it at `chat.jadee.fyi`. It talks to `http://127.0.0.1:8000/v1` with `OPENAI_API_KEY = "sk-no-auth"` (the server has no auth). `ENABLE_OLLAMA_API = "False"`.

## llama.cpp (`llama-cpp.nix`), router mode

The unit runs `llama-server --models-preset <generated INI> --models-max 2 --threads 8`. Each INI `[section]` name is a served model id. INI keys are long-form `llama-server` args without `--`. Local preset files accept the full arg set. Edit the `let` knobs, not raw args:

- Chat: `chatRepo` = `unsloth/gemma-4-12B-it-qat-GGUF`, `chatQuant` = `UD-Q4_K_XL`. This is the only quant in the QAT repo. Higher precision degrades QAT weights, so there is nothing to upgrade to.
- `chatCtx` = `131072` is the TOTAL pool. Each conversation gets `chatCtx / chatSlots`. `chatSlots` = `2`, so 64K per conversation.
- `chatKvType` = `q8_0`. It needs `flash-attn = on`. If Vulkan refuses, use `"f16"`.
- Chat sampling in the preset: `temp = 1.0`, `top-p = 0.95`, `top-k = 64`. Vision is on (`mmproj-auto = true`).
- Embed: `embedRepo` = `mradermacher/F2LLM-v2-0.6B-GGUF`, `embedQuant` = `Q8_0`, `embedCtx` = `8192`, `embedPooling` = `last` (Qwen3-arch embedders).
- `--models-max 2` keeps both models resident. `1` swaps on demand and gives chat the full VRAM.

**MTP (speculative decoding)** is not configured. The old blocker (missing `gemma4-assistant` draft arch) is resolved in the pinned llama.cpp. To enable it, add `spec-type = draft-mtp` and `spec-draft-n-max = 2` (range 1 to 6) to the `[local-chat]` preset. `hf-repo` finds the bundled drafter. Budget about +2 GB of VRAM. Make sure that the server comes up, because a drafter failure kills the whole preset.

## VRAM budget (15 GiB Arc B50)

QAT ~6.7 + mmproj ~1 + embedder ~0.6 + overhead ~1.5 ≈ 9.8 GB. About 5.2 GB remain for chat KV. Gemma 4 is cheap on KV (8 of 48 layers are full-attention, the rest cap at a 1024 sliding window), about 32 KiB/token at q8_0. 128K ≈ 4.2 GB, with about 1 GB margin. The true maximum is empirical. `journalctl -u llama-cpp-gemma` prints the KV size on load. `intel_gpu_top` shows VRAM. The comments in `llama-cpp.nix` carry the current math.

## Apply

Author changes locally. Never edit over SSH on mini.

1. `git add -A` (flakes only see tracked files).
2. `flake fmt` after `.nix` edits.
3. Eval-check the unit: `nix eval --raw .#nixosConfigurations.mini.config.systemd.services.llama-cpp-gemma.serviceConfig.ExecStart`.
4. Commit and push. `deploy` pulls `origin/main` on mini.
5. `just mini deploy` (pull, then `switch-fast`). Siblings: `just mini deploy-dry` (build only), `just mini deploy-boot` (stage for reboot).

The first boot downloads about 10 GB into `/var/lib/llama-cpp/huggingface`.

## Ops (`just mini llm <cmd>`)

`overview`, `status`, `logs`, `restart`, `models`, `chat [prompt]`, `perf`, `embedding [text]`, `gpu`, `troubleshoot`, `bench`. Script: `scripts/shell/mini-llm.bash` (targets `llama-cpp-gemma`).

`just mini llm status` is the first diagnostic. It prints the running `ExecStart` and flags drift from the flake output. Drift means the switch did not apply, or systemd runs a stale unit. Deploy again, then `restart`.

`bench` (llama-benchy) runs from any host. Keep `MINI_BENCH_CONCURRENCY` (default `1 2` in `just/mini-llm.just`) in sync with `chatSlots`. Requests past the slot count only measure queueing.
