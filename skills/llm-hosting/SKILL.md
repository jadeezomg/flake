---
name: llm-hosting
description: Change mini's local LLM serving (backend, models, context, embeddings). Use when editing hosts/mini/services/llm/**, switching between the vLLM and llama.cpp backends, tuning the served chat/embedding models, context/KV/slots, MTP, or the `just mini llm` ops, or when the local LLM fails to load/serve.
---

# LLM Hosting (mini)

## Scope

Local LLM serving on the **mini** host. Everything lives under `hosts/mini/services/llm/` plus the contract facts in `hosts/mini/host.nix`. Gated by `miniLlmHosting`. Reference docs: `docs/hosts/mini-llm-hosting.md` (ops + tuning) and `docs/hosts/mini-vllm-xpu.md` (XPU build/troubleshooting).

## The contract (single source of truth — `hosts/mini/host.nix`)

One chat endpoint, identical across backends, so consumers (`open-webui.nix`, `honcho.nix`) never change when you switch:

- `miniLlmBackend` — `"vllm"` | `"llamacpp"`. **Exactly one runs** (shared 15 GiB Arc B50; both OOM).
- `miniLlmServedName` — `"local-chat"`, the OpenAI chat model id.
- `miniLlmEmbedServedName` — `"local-embed"`, embeddings id (**llama.cpp backend only**).
- `miniLlmPort` `8000`, `miniLlmHost` `"0.0.0.0"` (tailnet-only; firewall trusts `tailscale0`).

`hosts/mini/services/llm/default.nix` is the aggregator + shared base (Intel GPU stack, HF token `mini-llm-hf.env`); it imports the selected backend + `open-webui.nix`.

## Switch backend

Set `miniLlmBackend` in `host.nix`, then apply. Consumers are unaffected (they read the contract). vLLM = Intel XPU (Qwen3.5-9B int4); llama.cpp = Vulkan (Gemma 4 12B QAT).

## llama.cpp backend (`llm/llama-cpp.nix`) — router mode

Runs `llama-server --models-preset <generated INI> --models-max 2`. The INI is built from `let` knobs; each `[section]` name = the served model id. Edit the knobs, not raw args:

- Chat: `chatRepo` / `chatQuant`, `chatCtx` (TOTAL pool — per-conversation = `chatCtx / chatSlots`), `chatSlots`, `chatKvType` (`q8_0` needs flash-attn; drop to `"f16"` if Vulkan refuses), `chatMtp`.
- Embed: `embedRepo` / `embedQuant`, `embedCtx`, `embedPooling` (`last` for Qwen3-arch embedders).
- `--models-max 2` keeps both resident; `1` swaps on demand (keeps chat at max ctx).
- INI keys are long-form `llama-server` args minus `--`; local preset files allow the full arg set.

**MTP (`chatMtp`)**: speculative decoding via the repo's `mtp-*.gguf` drafter. Keep **off** unless the packaged `llama-cpp` includes the `gemma4-assistant` draft arch (PR #23398) — otherwise the drafter fails with `unknown model architecture: 'gemma4-assistant'` and the server exits. The `--spec-type draft-mtp` flag existing is **not** proof the arch is supported.

## vLLM backend (`llm/vllm-xpu.nix`)

`services.vllm-xpu.instances.chat.*`: `model`, `quantization`, `kvCacheDtype`, `maxModelLen`, `maxNumSeqs`, `gpuMemoryUtilization`, `languageModelOnly` (`false` = vision on) + `limitMmPerPrompt`, `reasoningParser`, `extraArgs` (pin `--revision`). `instances.embedding` is defined but disabled (chat gets the whole budget). XPU vision is the **risky** path (chunk-prefill OOM) — see `mini-vllm-xpu.md`.

## VRAM budget (15 GiB B50)

KV is cheap on Gemma 4 (8 of 48 layers full-attention; rest cap at 1024 sliding) — ~32 KiB/token at q8_0. Leave headroom; the **true max is empirical** — `journalctl -u llama-cpp-gemma` prints KV size on load, `intel_gpu_top` shows VRAM. Comments in `llama-cpp.nix` carry the current math.

## Apply

1. `git add -A` (flakes only see tracked files).
2. `flake fmt` after `.nix` edits.
3. Eval-check the unit before switching, e.g. `nix eval --raw .#nixosConfigurations.mini.config.systemd.services.llama-cpp-gemma.serviceConfig.ExecStart`.
4. On mini: `just switch` (never bare `nixos-rebuild`/`nh`). First boot downloads models into `/var/lib/llama-cpp/huggingface`.

## Ops — `just mini llm <cmd>`

`overview` / `status` (backend-aware), `logs`, `restart`, `models`, `chat [prompt]`, `embedding [text]`, `perf`, `gpu`, `troubleshoot`, `bench`. Script: `scripts/shell/mini-llm.bash` (detects the active backend from the deployed unit). Keep `bench` concurrency (`just/mini-llm.just`) in sync with `chatSlots`.
