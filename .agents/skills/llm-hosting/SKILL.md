---
name: llm-hosting
description: Change mini's local LLM serving (llama.cpp models, context, embeddings). Use when editing hosts/mini/services/llm/**, tuning the served chat/embedding models, context/KV/slots, MTP, or the `just mini llm` ops, or when the local LLM fails to load/serve.
---

# LLM Hosting (mini)

## Scope

Local LLM serving on the **mini** host. Everything lives under `hosts/mini/services/llm/` plus the contract facts in `hosts/mini/host.nix`. Gated by `miniLlmHosting`. Reference doc: `docs/hosts/mini-llm-hosting.md` (ops + tuning).

## The contract (single source of truth — `hosts/mini/host.nix`)

Serving contract in `host.nix`:

- `miniLlmServedName` — `"local-chat"`, the OpenAI chat model id.
- `miniLlmEmbedServedName` — `"local-embed"`, embeddings id on the same port.
- `miniLlmPort` `8000`, `miniLlmHost` `"0.0.0.0"` (tailnet-only; firewall trusts `tailscale0`).

`hosts/mini/services/llm/default.nix` is the aggregator + shared base (Intel GPU stack, HF token `mini-llm-hf.env`); it imports `llama-cpp.nix` + `open-webui.nix`.

## llama.cpp (`llm/llama-cpp.nix`) — router mode

Runs `llama-server --models-preset <generated INI> --models-max 2`. The INI is built from `let` knobs; each `[section]` name = the served model id. Edit the knobs, not raw args:

- Chat: `chatRepo` / `chatQuant`, `chatCtx` (TOTAL pool — per-conversation = `chatCtx / chatSlots`), `chatSlots`, `chatKvType` (`q8_0` needs flash-attn; drop to `"f16"` if Vulkan refuses), `chatMtp`.
- Embed: `embedRepo` / `embedQuant`, `embedCtx`, `embedPooling` (`last` for Qwen3-arch embedders).
- `--models-max 2` keeps both resident; `1` swaps on demand (keeps chat at max ctx).
- INI keys are long-form `llama-server` args minus `--`; local preset files allow the full arg set.

**MTP (`chatMtp`)**: speculative decoding via the repo's `mtp-*.gguf` drafter. Keep **off** unless the packaged `llama-cpp` includes the `gemma4-assistant` draft arch (PR #23398) — otherwise the drafter fails with `unknown model architecture: 'gemma4-assistant'` and the server exits. The `--spec-type draft-mtp` flag existing is **not** proof the arch is supported.


## VRAM budget (15 GiB B50)

KV is cheap on Gemma 4 (8 of 48 layers full-attention; rest cap at 1024 sliding) — ~32 KiB/token at q8_0. Leave headroom; the **true max is empirical** — `journalctl -u llama-cpp-gemma` prints KV size on load, `intel_gpu_top` shows VRAM. Comments in `llama-cpp.nix` carry the current math.

## Apply

1. `git add -A` (flakes only see tracked files).
2. `flake fmt` after `.nix` edits.
3. Eval-check the unit before switching, e.g. `nix eval --raw .#nixosConfigurations.mini.config.systemd.services.llama-cpp-gemma.serviceConfig.ExecStart`.
4. On mini: `just switch` (never bare `nixos-rebuild`/`nh`). First boot downloads models into `/var/lib/llama-cpp/huggingface`.

## Ops — `just mini llm <cmd>`

`overview` / `status`, `logs`, `restart`, `models`, `chat [prompt]`, `embedding [text]`, `perf`, `gpu`, `troubleshoot`, `bench`. Script: `scripts/shell/mini-llm.bash` (targets `llama-cpp-gemma`). Keep `bench` concurrency (`just/mini-llm.just`) in sync with `chatSlots`.
