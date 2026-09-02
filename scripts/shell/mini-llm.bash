#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
root="${FLAKE:-$(cd "$script_dir/../.." && pwd)}"
source "$root/scripts/shell/common.sh"

# mini serves local LLMs via llama.cpp (`llama-cpp` systemd unit, router mode) on
# :8000 as `local-chat` / `local-embed`. Config: hosts/mini/services/llm/default.nix.

usage() {
  cat <<'USAGE'
usage: mini-llm.bash <command> [arg]

commands:
  overview               backend + unit status, runtime command, model probes
  status                 service status for the active LLM backend
  logs                   follow logs for the active backend's unit(s)
  restart                restart the active backend's unit(s)
  models                 list served models on :8000
  chat [prompt]          smoke-test chat on :8000 (model local-chat)
  perf [prompt]          throughput probe: complex prompt, reports TTFT + tok/s
  embedding [text]       smoke-test embeddings (`local-embed` on :8000)
  gpu                    live Intel GPU utilization
  troubleshoot           backend, failed units, cache paths, recent logs
USAGE
}

# Which backend is deployed right now (by which unit file exists), not what is running.
primary_unit() {
  if systemctl cat llama-cpp.service >/dev/null 2>&1; then
    echo llama-cpp
  else
    echo ""
  fi
}

# Legacy name kept for callers.
active_backend() {
  if primary_unit | grep -q .; then
    echo llamacpp
  else
    echo none
  fi
}


# All units for the active backend (space-separated).
backend_units() {
  primary_unit
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
      print_info "Try: just mini llm logs"
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
  # Heavier check: a complex prompt that forces sustained generation, so the numbers
  # reflect real decode throughput rather than the 8-token smoke test. Backend-agnostic
  # (model = local-chat); on llama.cpp this also exercises the MTP speculative path.
  local prompt max_tokens body line payload start end
  local first="" prompt_tokens="" completion_tokens=""
  prompt="${1:-Explain in depth how a modern out-of-order CPU executes a stream of instructions: fetch, decode, register renaming, reservation stations, execution ports, the reorder buffer, and retirement. Give concrete examples and explain why each stage exists.}"
  max_tokens="${MINI_LLM_PERF_TOKENS:-256}"

  print_header "throughput probe (complex prompt)"
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
    print_info "Inspect: just mini llm logs"
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

# Show the active backend's running command and warn if it drifted from the flake
# (switch not applied / stale unit). Backend-agnostic: just compares ExecStart.
show_runtime_config() {
  local unit exec_start expected
  unit="$(primary_unit)"
  if [[ -z "$unit" ]]; then
    print_pending "no active LLM backend on this host"
    return
  fi
  exec_start="$(systemctl show "${unit}.service" --property=ExecStart --value 2>/dev/null || true)"
  expected="$(nix eval --raw "$root#nixosConfigurations.mini.config.systemd.services.${unit}.serviceConfig.ExecStart" 2>/dev/null || true)"

  print_header "RUNTIME COMMAND ($unit)"
  if [[ -z "$exec_start" ]]; then
    print_pending "${unit} ExecStart unavailable"
    return
  fi
  printf '%s\n' "$exec_start"

  if [[ -n "$expected" && "$exec_start" != *"$expected"* ]]; then
    print_error "Running unit does not match the current flake output."
    print_info "This usually means the switch did not apply, or systemd is using an older unit."
    print_info "On mini: git add -A && just switch && sudo systemctl daemon-reload && sudo systemctl restart $unit"
    print_pending "expected: $expected"
  else
    print_success "Running unit matches the flake output."
  fi
}

command_name="${1:-}"
shift || true

case "$command_name" in
overview | status)
  be="$(active_backend)"
  print_header "MINI LLM STATUS (backend: $be)"
  systemctl list-units 'llama-cpp*' --all --no-pager --full
  print_header "UNIT STATUS"
  mapfile -t units < <(backend_units | tr ' ' '\n' | grep -v '^$' || true)
  if ((${#units[@]})); then
    systemctl --no-pager --full --lines=80 status "${units[@]}" || true
  fi
  show_runtime_config
  if [[ "$command_name" == "overview" ]]; then
    probe "models :8000" "http://127.0.0.1:8000/v1/models"
    unit="$(primary_unit)"
    if [[ -n "$unit" && "$(systemctl is-active "${unit}.service" 2>/dev/null || true)" == "active" ]]; then
      perf_probe || true
    fi
  fi
  ;;
logs)
  mapfile -t units < <(backend_units | tr ' ' '\n' | grep -v '^$' || true)
  if ((${#units[@]} == 0)); then
    print_error "No LLM backend is active on this host."
    exit 1
  fi
  args=()
  for u in "${units[@]}"; do args+=(-u "$u"); done
  journalctl --no-pager -f "${args[@]}"
  ;;
restart)
  mapfile -t units < <(backend_units | tr ' ' '\n' | grep -v '^$' || true)
  if ((${#units[@]} == 0)); then
    print_error "No LLM backend is active on this host."
    exit 1
  fi
  sudo systemctl restart "${units[@]}"
  systemctl --no-pager status "${units[@]}" || true
  ;;
models)
  probe "models :8000" "http://127.0.0.1:8000/v1/models"
  ;;
chat)
  prompt="${1:-Reply with exactly: ok}"
  require_endpoint "chat :8000" "http://127.0.0.1:8000/v1/models" "$(primary_unit)"
  print_header "chat request (local-chat)"
  print_pending "POST /v1/chat/completions model=local-chat max_tokens=8 stream=true enable_thinking=false"
  print_info "Smoke test: short output, thinking disabled. If it crawls, watch: just mini llm logs"
  jq -n --arg prompt "$prompt" \
    '{model:"local-chat",messages:[{role:"user",content:$prompt}],max_tokens:8,stream:true,chat_template_kwargs:{enable_thinking:false}}' |
    xh --stream --timeout=120 POST http://127.0.0.1:8000/v1/chat/completions Content-Type:application/json
  ;;
perf)
  require_endpoint "chat :8000" "http://127.0.0.1:8000/v1/models" "$(primary_unit)"
  perf_probe "${1:-}"
  ;;
embedding)
  text="${1:-The quick brown fox jumps over the lazy dog.}"
  unit="$(primary_unit)"
  if [[ -z "$unit" ]]; then
    print_error "No LLM backend is active on this host."
    exit 1
  fi
  require_endpoint "embeddings :8000" "http://127.0.0.1:8000/v1/models" "$unit"
  print_header "embeddings request (local-embed)"
  print_pending "POST /v1/embeddings model=local-embed"
  jq -n --arg t "$text" '{model:"local-embed",input:$t}' |
    xh --timeout=60 POST http://127.0.0.1:8000/v1/embeddings Content-Type:application/json |
    jq '{model: .model, dims: (.data[0].embedding | length), usage: .usage}'
  ;;
gpu)
  sudo intel_gpu_top
  ;;
troubleshoot)
  print_header "ACTIVE BACKEND"
  printf '%s\n' "$(active_backend)"
  print_header "FAILED UNITS"
  systemctl --no-pager --failed || true
  print_header "LLM UNITS"
  systemctl list-units 'llama-cpp*' --all --no-pager --full
  show_runtime_config
  print_header "CACHE PATHS"
  for path in /var/cache/ccache /var/lib/llama-cpp /var/lib/llama-cpp/huggingface /var/lib/private/sops/age; do
    if [[ -e "$path" ]]; then
      stat -c '%A %U:%G %n' "$path"
    else
      print_pending "missing $path"
    fi
  done
  print_header "RECENT LOGS"
  mapfile -t units < <(backend_units | tr ' ' '\n' | grep -v '^$' || true)
  if ((${#units[@]})); then
    args=()
    for u in "${units[@]}"; do args+=(-u "$u"); done
    journalctl --no-pager "${args[@]}" -n 120 || true
  fi
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
