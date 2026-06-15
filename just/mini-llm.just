# Mini LLM service ops — nested under the `mini` module as `just mini llm <cmd>`.
# Operate the active LLM backend *on mini* (systemctl, journals, 127.0.0.1): either
# the llama.cpp router (`local-chat` + `local-embed`) or vLLM-XPU, auto-detected from
# the deployed unit. `bench` is the exception — it hits the OpenAI API over the network
# and can run from any host. $FLAKE is inherited from the root Justfile's export.
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

[doc('List served models on :8000 (+ :8001 if vLLM embeddings)')]
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

[doc('Smoke-test embeddings (local-embed on llama.cpp, or vLLM :8001)')]
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
    # id llama-benchy uses for tokenizer-based token counting, so it should match the
    # active backend's underlying model. Defaults to the llama.cpp Gemma 4 QAT repo;
    # override with MINI_BENCH_MODEL (e.g. Intel/Qwen3.5-9B-int4-AutoRound for vLLM).
    bench_model="${MINI_BENCH_MODEL:-unsloth/gemma-4-12B-it-qat-GGUF}"
    # Default sweep if the caller passes nothing; any args override it.
    if [[ $# -eq 0 ]]; then
      set -- --pp 2048 --tg 128 --depth 0 4096 16384 32768 \
             --concurrency 1 8 --latency-mode generation --exact-tg
    fi
    exec uvx llama-benchy \
      --base-url "$base_url" \
      --model "$bench_model" \
      --served-model-name local-chat \
      "$@"
