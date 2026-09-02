# Mini LLM service ops — nested under the `mini` module as `just mini llm <cmd>`.
# Operate the llama.cpp router on mini (`local-chat` + `local-embed`). `bench` hits
# the OpenAI API over the network and can run from any host. $FLAKE is inherited from
# the root Justfile's export.
set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

[doc('Dashboard: backend + status + runtime command + model probes')]
overview:
    @bash "$FLAKE/scripts/shell/mini-llm.bash" overview

[doc('Service status for the active LLM backend')]
status:
    @bash "$FLAKE/scripts/shell/mini-llm.bash" status

[doc("Follow logs for the active backend's unit(s)")]
logs:
    @bash "$FLAKE/scripts/shell/mini-llm.bash" logs

[doc("Restart the active backend's unit(s)")]
restart:
    @bash "$FLAKE/scripts/shell/mini-llm.bash" restart

[doc('List served models on :8000')]
models:
    @bash "$FLAKE/scripts/shell/mini-llm.bash" models

[doc('Smoke-test chat on :8000 (model local-chat)')]
[positional-arguments]
chat *args:
    @bash "$FLAKE/scripts/shell/mini-llm.bash" chat "$@"

[doc('Throughput probe on :8000; complex prompt, reports TTFT + tok/s')]
[positional-arguments]
perf *args:
    @bash "$FLAKE/scripts/shell/mini-llm.bash" perf "$@"

[doc('Smoke-test embeddings (`local-embed` on :8000)')]
[positional-arguments]
embedding *args:
    @bash "$FLAKE/scripts/shell/mini-llm.bash" embedding "$@"

[doc('Live Intel GPU utilization')]
gpu:
    @bash "$FLAKE/scripts/shell/mini-llm.bash" gpu

[doc('Troubleshooting snapshot')]
troubleshoot:
    @bash "$FLAKE/scripts/shell/mini-llm.bash" troubleshoot

[doc('Rigorous benchmark via llama-benchy (pp/tg at depths + concurrency); runs from any host')]
[positional-arguments]
bench *args:
    #!/usr/bin/env bash
    set -euo pipefail
    # uv's downloaded standalone Python bypasses the nix-ld loader, so PyPI
    # numpy/tokenizers wheels can't find libstdc++. nix-ld already populates the
    # needed libs (declared in modules/nixos/nix-ld.nix), so point the loader path
    # at that dir for this run.
    export LD_LIBRARY_PATH="/run/current-system/sw/share/nix-ld/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    # Targets the tailnet API by default; override with MINI_API=http://127.0.0.1:8000/v1
    # to run on mini itself (no network jitter).
    base_url="${MINI_API:-http://mini:8000/v1}"
    # --served-model-name is the shared contract (local-chat); --model is only the HF
    # repo llama-benchy loads a tokenizer from for prompt-token counting. GGUF repos ship
    # NO HF tokenizer files, so point at the *source* (safetensors) repo with a
    # tokenizer.json — same tokenizer as the served GGUF, just accurate counts instead of
    # the gpt2 fallback. Defaults to the Gemma 4 source repo (ungated); override with
    # MINI_BENCH_MODEL (HF tokenizer source repo for token counting).
    bench_model="${MINI_BENCH_MODEL:-unsloth/gemma-4-12b-it}"
    # Default sweep if the caller passes nothing; any args override it.
    # Concurrency tops out at the server's slot count — keep it in sync with
    # `models.local-chat.slots` / `--parallel` in hosts/mini/services/llm/default.nix (2 today).
    # Requests beyond the slot count just queue, so testing past it measures queueing,
    # not throughput. Override per run with MINI_BENCH_CONCURRENCY (space-separated).
    concurrency="${MINI_BENCH_CONCURRENCY:-1 2}"
    if [[ $# -eq 0 ]]; then
      set -- --pp 2048 --tg 128 --depth 0 4096 16384 32768 \
             --concurrency $concurrency --latency-mode generation --exact-tg
    fi
    # sentencepiece (+protobuf) is a fallback for model repos that ship only a slow
    # tokenizer; with the tokenizer.json source repo above it builds a fast tokenizer
    # directly. (torch is not needed for tokenizing — its "not found" warning is harmless.)
    exec uvx --with sentencepiece --with protobuf llama-benchy \
      --base-url "$base_url" \
      --model "$bench_model" \
      --served-model-name local-chat \
      "$@"
