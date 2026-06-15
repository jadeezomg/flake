# Task 2 — Finalize honcho LLM wiring + embeddings (Phase 1 tail)

**State:** honcho deployed and healthy (4 containers: `honcho-db`/`-redis`/`-api`/`-deriver`), reachable at `https://mini.quokka-qilin.ts.net:8100` (`/health` ok, `/docs` Swagger). API↔DB↔Redis verified; container→local-LLM reachability fixed via a pinned podman subnet (`10.89.0.0/24`) + iptables allow in `hosts/mini/services/honcho.nix`.

## What's left
1. **Per-feature LLM endpoints.** Only `DERIVER_MODEL_CONFIG__*` points at the local chat server (`http://host.containers.internal:<miniLlmPort>/v1`, model `host.miniLlmServedName`). Other features (dialectic, summary, …) will fall back to `api.openai.com` with the placeholder key. Add `<FEATURE>_MODEL_CONFIG__TRANSPORT/MODEL/OVERRIDES__BASE_URL` for each, pointing at the local server. Confirm exact feature names from honcho config docs (https://honcho.dev/docs) and by reading `podman-honcho-api`/`-deriver` logs while exercising a query.
2. **Embeddings.** Currently `EMBED_MESSAGES=false` (chosen for a clean first boot — semantic search off). Re-enable and point `EMBEDDING_MODEL_CONFIG__*` at a local embedding endpoint. mini's vLLM jina embedding instance is currently disabled — enable it (see `vllm-xpu.nix` `instances.embedding`) or pick another, mind the vector dimensions vs `EMBEDDING_VECTOR_DIMENSIONS`.

## How to exercise / verify
- The deriver **batches** below `DERIVER_REPRESENTATION_BATCH_MAX_TOKENS` (1024), so tiny test messages stay queued (`/v3/workspaces/<ws>/queue/status`). Either post enough message tokens, or set `DERIVER_FLUSH_ENABLED=true` to force immediate processing, then watch the deriver log hit the local LLM (no `api.openai.com` errors).
- v3 API is `/v3/workspaces/{ws}/peers|sessions|messages…`; `USE_AUTH=false` (tailnet-gated).

## Files
- `hosts/mini/services/honcho.nix` (env in the `honchoEnv` let-binding). Provider keys → optional sops `honcho/env`.

## Suggested skills
- `diagnose` (trace the LLM call path), `verify`.
