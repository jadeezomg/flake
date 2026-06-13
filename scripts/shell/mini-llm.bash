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
  models                 list OpenAI-compatible models on 8000/8001/8010
  chat [prompt]          smoke-test vLLM chat on 8000
  embedding [text]       smoke-test vLLM embeddings on 8001
  gpu                    live Intel GPU utilization
  troubleshoot           failed units, cache paths, recent logs
USAGE
}

unit_args() {
  local unit="${1:-all}"
  case "$unit" in
  all) printf '%s\0' vllm-xpu-chat vllm-xpu-embedding llama-cpp-gemma ;;
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
  all) printf '%s\0%s\0%s\0%s\0%s\0%s\0' -u vllm-xpu-chat -u vllm-xpu-embedding -u llama-cpp-gemma ;;
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
  local out
  if ! out="$(xh --ignore-stdin --timeout=5 GET "$url" 2>&1)"; then
    print_error "$label is not reachable."
    print_info "The HTTP API is not listening yet; check the systemd unit before running the smoke test."
    print_info "Try: just mini-llm-status"
    print_info "Try: just mini-llm-logs ${unit#vllm-xpu-}"
    print_pending "$out"
    exit 1
  fi
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

command_name="${1:-}"
shift || true

case "$command_name" in
overview)
  print_header "MINI LLM STATUS"
  systemctl list-units 'vllm-xpu-*' 'llama-cpp-*' --all --no-pager
  print_header "UNIT STATUS"
  systemctl --no-pager status vllm-xpu-chat vllm-xpu-embedding llama-cpp-gemma || true
  probe "vLLM chat :8000" "http://127.0.0.1:8000/v1/models"
  probe "vLLM embeddings :8001" "http://127.0.0.1:8001/v1/models"
  probe "llama.cpp :8010" "http://127.0.0.1:8010/v1/models"
  ;;
status)
  print_header "MINI LLM STATUS"
  systemctl list-units 'vllm-xpu-*' 'llama-cpp-*' --all --no-pager
  print_header "UNIT STATUS"
  systemctl --no-pager status vllm-xpu-chat vllm-xpu-embedding llama-cpp-gemma || true
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
  probe "vLLM chat :8000" "http://127.0.0.1:8000/v1/models"
  probe "vLLM embeddings :8001" "http://127.0.0.1:8001/v1/models"
  probe "llama.cpp :8010" "http://127.0.0.1:8010/v1/models"
  ;;
chat)
  prompt="${1:-Hello}"
  require_endpoint "vLLM chat :8000" "http://127.0.0.1:8000/v1/models" "vllm-xpu-chat"
  jq -n --arg prompt "$prompt" \
    '{model:"qwen3.5-9b",messages:[{role:"user",content:$prompt}],max_tokens:64,stream:false}' |
    xh --timeout=600 POST http://127.0.0.1:8000/v1/chat/completions Content-Type:application/json
  ;;
embedding)
  text="${1:-hello}"
  require_endpoint "vLLM embeddings :8001" "http://127.0.0.1:8001/v1/models" "vllm-xpu-embedding"
  jq -n --arg text "$text" \
    '{model:"jina-embeddings-v5-nano",input:$text}' |
    xh --timeout=120 POST http://127.0.0.1:8001/v1/embeddings Content-Type:application/json
  ;;
gpu)
  sudo intel_gpu_top
  ;;
troubleshoot)
  print_header "FAILED UNITS"
  systemctl --no-pager --failed || true
  print_header "LLM UNITS"
  systemctl list-units 'vllm-xpu-*' 'llama-cpp-*' --all --no-pager
  print_header "CACHE PATHS"
  for path in /var/cache/ccache /var/lib/llama-cpp /var/lib/private/sops/age; do
    if [[ -e "$path" ]]; then
      stat -c '%A %U:%G %n' "$path"
    else
      print_pending "missing $path"
    fi
  done
  print_header "RECENT LOGS"
  journalctl --no-pager -u vllm-xpu-chat -u vllm-xpu-embedding -u llama-cpp-gemma -n 120 || true
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
