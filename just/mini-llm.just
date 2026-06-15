# Mini LLM service ops — nested under the `mini` module as `just mini llm <cmd>`.
# These operate the vLLM-XPU / llama.cpp services *on mini* (systemctl, journals,
# 127.0.0.1), except `bench`, which hits the OpenAI API over the network and can
# run from any host. $FLAKE is inherited from the root Justfile's export.
set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

[doc('Dashboard: status + runtime flags + model probes')]
overview:
    @bash "$FLAKE/scripts/shell/mini-llm.bash" overview

[doc('Service status (vLLM-XPU chat/embed + optional llama.cpp)')]
status:
    @bash "$FLAKE/scripts/shell/mini-llm.bash" status

[doc('Follow logs; unit = all|chat|embedding|llama')]
[positional-arguments]
logs *args:
    @bash "$FLAKE/scripts/shell/mini-llm.bash" logs "$@"

[doc('Restart units; unit = all|chat|embedding|llama')]
[positional-arguments]
restart *args:
    @bash "$FLAKE/scripts/shell/mini-llm.bash" restart "$@"

[doc('List OpenAI-compatible models on 8000 (active backend)')]
models:
    @bash "$FLAKE/scripts/shell/mini-llm.bash" models

[doc('Smoke-test vLLM chat on 8000 (short reply)')]
[positional-arguments]
chat *args:
    @bash "$FLAKE/scripts/shell/mini-llm.bash" chat "$@"

[doc('Throughput probe on 8000; complex prompt, reports TTFT + tok/s')]
[positional-arguments]
perf *args:
    @bash "$FLAKE/scripts/shell/mini-llm.bash" perf "$@"

[doc('Smoke-test vLLM embeddings on 8001')]
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
    # Default sweep if the caller passes nothing; any args override it.
    if [[ $# -eq 0 ]]; then
      set -- --pp 2048 --tg 128 --depth 0 4096 16384 32768 \
             --concurrency 1 8 --latency-mode generation --exact-tg
    fi
    exec uvx llama-benchy \
      --base-url "$base_url" \
      --model Intel/Qwen3.5-9B-int4-AutoRound \
      --served-model-name local-chat \
      "$@"
