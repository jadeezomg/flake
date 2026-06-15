#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
root="${FLAKE:-$(cd "$script_dir/../.." && pwd)}"
source "$root/scripts/shell/common.sh"

usage() {
  cat <<'USAGE'
usage: mini-llm.bash <command> [arg]

commands:
  overview               status plus model probes; safe default from picker
  status                 service status for vLLM-XPU and llama.cpp
  logs [all|chat|embedding|llama]
  restart [all|chat|embedding|llama]
  models                 list OpenAI-compatible models on 8000 (active backend)
  chat [prompt]          smoke-test vLLM chat on 8000 (short reply)
  perf [prompt]          throughput probe: complex prompt, reports TTFT + tok/s
  embedding [text]       disabled for now; chat gets the whole XPU budget
  gpu                    live Intel GPU utilization
  troubleshoot           failed units, cache paths, recent logs
USAGE
}

unit_args() {
  local unit="${1:-all}"
  case "$unit" in
  all) printf '%s\0' vllm-xpu-chat llama-cpp-gemma ;;
  chat) printf '%s\0' vllm-xpu-chat ;;
  embedding) printf '%s\0' vllm-xpu-embedding ;;
  llama) printf '%s\0' llama-cpp-gemma ;;
  *)
    print_error "Usage: $0 ${2:-logs} [all|chat|embedding|llama]"
    exit 2
    ;;
  esac
}

journal_unit_args() {
  local unit="${1:-all}"
  case "$unit" in
  all) printf '%s\0%s\0%s\0%s\0' -u vllm-xpu-chat -u llama-cpp-gemma ;;
  chat) printf '%s\0%s\0' -u vllm-xpu-chat ;;
  embedding) printf '%s\0%s\0' -u vllm-xpu-embedding ;;
  llama) printf '%s\0%s\0' -u llama-cpp-gemma ;;
  *)
    print_error "Usage: $0 logs [all|chat|embedding|llama]"
    exit 2
    ;;
  esac
}

require_endpoint() {
  local label="$1" url="$2" unit="$3"
  local timeout="${MINI_LLM_WAIT_SECONDS:-300}"
  local started="$SECONDS"
  local out state elapsed

  while true; do
    if out="$(xh --ignore-stdin --timeout=5 GET "$url" 2>&1)"; then
      return
    fi

    elapsed=$((SECONDS - started))
    if ((elapsed >= timeout)); then
      print_error "$label is not reachable after ${timeout}s."
      print_info "The HTTP API is still not listening; inspect the systemd unit before running the smoke test."
      print_info "Try: just mini llm status"
      print_info "Try: just mini llm logs ${unit#vllm-xpu-}"
      print_pending "$out"
      print_header "${unit}.service status"
      systemctl --no-pager --full --lines=80 status "${unit}.service" || true
      print_header "${unit}.service recent logs"
      journalctl --no-pager -u "${unit}.service" -n 80 || true
      exit 1
    fi

    state="$(systemctl is-active "${unit}.service" 2>/dev/null || true)"
    if [[ "$state" != "active" && "$state" != "activating" ]]; then
      print_error "$label cannot start because ${unit}.service is ${state:-unknown}."
      print_header "${unit}.service status"
      systemctl --no-pager --full --lines=80 status "${unit}.service" || true
      print_header "${unit}.service recent logs"
      journalctl --no-pager -u "${unit}.service" -n 80 || true
      exit 1
    fi

    print_pending "$label not ready yet (${elapsed}s/${timeout}s); ${unit}.service is $state"
    sleep 5
  done
}

probe() {
  local label="$1" url="$2"
  local out
  print_header "$label"
  if out="$(xh --ignore-stdin --timeout=10 GET "$url" 2>&1)"; then
    printf '%s\n' "$out"
  else
    print_pending "$label unavailable"
  fi
}

perf_probe() {
  # Second, heavier check: a complex prompt that forces sustained generation, so
  # the numbers reflect real decode throughput rather than the 8-token smoke test.
  local prompt max_tokens body line payload start end
  local first="" prompt_tokens="" completion_tokens=""
  prompt="${1:-Explain in depth how a modern out-of-order CPU executes a stream of instructions: fetch, decode, register renaming, reservation stations, execution ports, the reorder buffer, and retirement. Give concrete examples and explain why each stage exists.}"
  max_tokens="${MINI_LLM_PERF_TOKENS:-256}"

  print_header "vLLM throughput probe (complex prompt)"
  print_pending "POST /v1/chat/completions model=local-chat max_tokens=$max_tokens stream=true (TTFT + decode tok/s)"

  body="$(jq -n --arg prompt "$prompt" --argjson max "$max_tokens" \
    '{model:"local-chat",messages:[{role:"user",content:$prompt}],max_tokens:$max,stream:true,stream_options:{include_usage:true},chat_template_kwargs:{enable_thinking:false}}')"

  start="$(date +%s.%N)"
  while IFS= read -r line; do
    [[ "$line" == data:* ]] || continue
    payload="${line#data: }"
    payload="${payload# }"
    [[ "$payload" == "[DONE]" ]] && continue
    # Stamp first-token time off a cheap glob (no jq) so TTFT excludes parse cost.
    if [[ -z "$first" && "$payload" == *'"content":"'* && "$payload" != *'"content":""'* ]]; then
      first="$(date +%s.%N)"
    fi
    # The include_usage final chunk carries exact server-side token counts.
    if [[ "$payload" == *'"usage"'* && "$payload" == *'completion_tokens'* ]]; then
      completion_tokens="$(jq -r '.usage.completion_tokens // empty' <<<"$payload" 2>/dev/null)"
      prompt_tokens="$(jq -r '.usage.prompt_tokens // empty' <<<"$payload" 2>/dev/null)"
    fi
  done < <(printf '%s' "$body" | xh --stream --timeout=180 POST http://127.0.0.1:8000/v1/chat/completions Content-Type:application/json)
  end="$(date +%s.%N)"

  if [[ -z "$completion_tokens" || -z "$first" ]]; then
    print_error "Throughput probe did not complete (no tokens or no usage chunk)."
    print_info "Inspect: just mini llm logs chat"
    return 1
  fi

  awk -v s="$start" -v f="$first" -v e="$end" -v ct="$completion_tokens" -v pt="${prompt_tokens:-0}" 'BEGIN{
    ttft=f-s; dec=e-f; tot=e-s;
    printf "  prompt tokens : %s\n", pt;
    printf "  output tokens : %s\n", ct;
    printf "  TTFT (prefill): %.3f s\n", ttft;
    if (dec>0 && ct>1) printf "  decode speed  : %.1f tok/s\n", (ct-1)/dec;
    if (tot>0)         printf "  end-to-end    : %.1f tok/s over %.2f s\n", ct/tot, tot;
  }'
}

show_chat_runtime_config() {
  local exec_start expected_exec_start
  exec_start="$(systemctl show vllm-xpu-chat.service --property=ExecStart --value 2>/dev/null || true)"
  expected_exec_start="$(nix eval --raw "$root#nixosConfigurations.mini.config.systemd.services.vllm-xpu-chat.serviceConfig.ExecStart" 2>/dev/null || true)"

  print_header "CHAT RUNTIME FLAGS"
  if [[ -z "$exec_start" ]]; then
    print_pending "vllm-xpu-chat ExecStart unavailable"
    return
  fi
  printf '%s\n' "$exec_start"

  if [[ -n "$expected_exec_start" && "$exec_start" != *"$expected_exec_start"* ]]; then
    print_error "Running chat unit does not match the current flake output."
    print_info "This usually means the switch did not apply, or systemd is still using an older unit."
    print_info "Run on mini: NIX_CONFIG='cores = 1' just switch-fast && sudo systemctl daemon-reload && sudo systemctl restart vllm-xpu-chat"
    print_pending "expected ExecStart: $expected_exec_start"
  fi

  local missing=()
  case "$exec_start" in *"--language-model-only"*) ;; *) missing+=("--language-model-only") ;; esac
  case "$exec_start" in *"--enforce-eager"*) ;; *) missing+=("--enforce-eager") ;; esac
  case "$exec_start" in *"--max-num-seqs 8"*) ;; *) missing+=("--max-num-seqs 8") ;; esac

  if ((${#missing[@]})); then
    print_error "Running chat unit is missing expected mini tuning: ${missing[*]}"
    print_info "Run from this repo on mini: git add -A && just switch"
  else
    print_success "Running chat unit has expected mini tuning flags"
  fi
}

command_name="${1:-}"
shift || true

case "$command_name" in
overview)
  print_header "MINI LLM STATUS"
  systemctl list-units 'vllm-xpu-*' 'llama-cpp-*' --all --no-pager --full
  print_header "UNIT STATUS"
  systemctl --no-pager --full --lines=80 status vllm-xpu-chat llama-cpp-gemma || true
  show_chat_runtime_config
  # Both backends serve the shared contract on :8000; only one is active at a time.
  probe "local chat :8000" "http://127.0.0.1:8000/v1/models"
  if [[ "$(systemctl is-active vllm-xpu-chat.service 2>/dev/null || true)" == "active" ]]; then
    perf_probe || true
  fi
  ;;
status)
  print_header "MINI LLM STATUS"
  systemctl list-units 'vllm-xpu-*' 'llama-cpp-*' --all --no-pager --full
  print_header "UNIT STATUS"
  systemctl --no-pager --full --lines=80 status vllm-xpu-chat llama-cpp-gemma || true
  show_chat_runtime_config
  ;;
logs)
  mapfile -d '' -t args < <(journal_unit_args "${1:-all}")
  journalctl --no-pager -f "${args[@]}"
  ;;
restart)
  mapfile -d '' -t units < <(unit_args "${1:-all}" restart)
  sudo systemctl restart "${units[@]}"
  systemctl --no-pager status "${units[@]}" || true
  ;;
models)
  probe "local chat :8000" "http://127.0.0.1:8000/v1/models"
  ;;
chat)
  prompt="${1:-Reply with exactly: ok}"
  require_endpoint "vLLM chat :8000" "http://127.0.0.1:8000/v1/models" "vllm-xpu-chat"
  print_header "vLLM chat request"
  print_pending "POST /v1/chat/completions model=local-chat max_tokens=8 stream=true enable_thinking=false"
  print_info "This is a smoke test: short output, Qwen thinking disabled. If it still crawls, watch: just mini llm logs chat"
  jq -n --arg prompt "$prompt" \
    '{model:"local-chat",messages:[{role:"user",content:$prompt}],max_tokens:8,stream:true,chat_template_kwargs:{enable_thinking:false}}' |
    xh --stream --timeout=120 POST http://127.0.0.1:8000/v1/chat/completions Content-Type:application/json
  ;;
perf)
  require_endpoint "vLLM chat :8000" "http://127.0.0.1:8000/v1/models" "vllm-xpu-chat"
  perf_probe "${1:-}"
  ;;
embedding)
  print_error "vLLM embeddings are disabled on mini so chat can use the full XPU memory budget."
  print_info "Re-enable services.vllm-xpu.instances.embedding in hosts/mini/services/vllm-xpu.nix if you need :8001 again."
  exit 1
  ;;
gpu)
  sudo intel_gpu_top
  ;;
troubleshoot)
  print_header "FAILED UNITS"
  systemctl --no-pager --failed || true
  print_header "LLM UNITS"
  systemctl list-units 'vllm-xpu-*' 'llama-cpp-*' --all --no-pager --full
  show_chat_runtime_config
  print_header "CACHE PATHS"
  for path in /var/cache/ccache /var/lib/llama-cpp /var/lib/private/sops/age; do
    if [[ -e "$path" ]]; then
      stat -c '%A %U:%G %n' "$path"
    else
      print_pending "missing $path"
    fi
  done
  print_header "RECENT LOGS"
  journalctl --no-pager -u vllm-xpu-chat -u llama-cpp-gemma -n 120 || true
  ;;
-h | --help | help | "")
  usage
  ;;
*)
  print_error "Unknown mini LLM command: $command_name"
  usage
  exit 2
  ;;
esac
