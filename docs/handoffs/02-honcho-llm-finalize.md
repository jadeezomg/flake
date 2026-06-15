# Task 2 — Honcho finalize: LLM wiring + embeddings + agent integrations

**Server state:** honcho deployed and healthy (4 containers: `honcho-db`/`-redis`/`-api`/`-deriver`).
- Bind: `127.0.0.1:8100` on mini (loopback); `tailscale serve` fronts HTTPS at `https://mini.quokka-qilin.ts.net:8100`.
- API is **v3-only** — verified by probe: `/v1` + `/v2` → 404, `/v3/workspaces/{ws}/queue/status` → 200. `GET /openapi.json` → title "Honcho API", version **3.0.9**. (Note `/` and `/v3` themselves are unmapped → 404; that's expected, the app is up.)
- `USE_AUTH=false` (tailnet-gated). A **dummy bearer** (`sk-no-auth`) is accepted; SDKs treat **local/loopback `baseUrl`** as auth-skip + auto-enable.
- Container→local-LLM reachability fixed via pinned podman subnet (`10.89.0.0/24`) + iptables allow in `hosts/mini/services/honcho.nix`.

---

## Shared-memory model (decided + wired)

One workspace, one user peer, distinct AI peers — so **all agents on all hosts read/write the same memory**:

| | value |
|---|---|
| workspace | `jadee` |
| user peer (`peerName`) | `jadee` |
| AI peer — Claude Code | `claude` |
| AI peer — hermes | `hermes` |
| AI peer — omp | `omp` |

⚠️ **Gotcha:** per-tool defaults split memory (claude-honcho defaults the workspace to `claude_code`/`cursor`/`obsidian`). The shared workspace **must be pinned** to `jadee` on every client, or agents get separate memories.

---

## Pending — LLM wiring + embeddings (original Task 2, still open)

1. **Per-feature LLM endpoints.** Only `DERIVER_MODEL_CONFIG__*` points at the local chat tier (`http://host.containers.internal:<miniLlmPort>/v1`, served name `host.miniLlmServedName` — abstracted across vLLM/llamacpp in `host.nix`). Other features (dialectic, summary, …) fall back to `api.openai.com` with the placeholder key. Add `<FEATURE>_MODEL_CONFIG__TRANSPORT/MODEL/OVERRIDES__BASE_URL` for each. Confirm exact feature names from honcho config docs (https://honcho.dev/docs) and `podman-honcho-api`/`-deriver` logs while exercising a query.
2. **Embeddings.** Currently `EMBED_MESSAGES=false` (clean first boot — semantic search off). Re-enable and point `EMBEDDING_MODEL_CONFIG__*` at a local embedding endpoint. mini's vLLM jina embedding instance is currently disabled — enable it (`hosts/mini/services/llm/vllm-xpu.nix` `instances.embedding`) or pick another; mind vector dims vs `EMBEDDING_VECTOR_DIMENSIONS`.

**Exercise/verify:** the deriver **batches** below `DERIVER_REPRESENTATION_BATCH_MAX_TOKENS` (1024), so tiny test messages stay queued (`/v3/workspaces/<ws>/queue/status`). Post enough message tokens, or set `DERIVER_FLUSH_ENABLED=true` to force processing, then watch the deriver log hit the local LLM (no `api.openai.com` errors).

---

## Agent integrations (Phase 3 — done this session)

### ✅ Claude Code — committed + live
- Plugin **`plastic-labs/claude-honcho`** (marketplace `honcho`), enabled in `data/agents/global/settings.json`:
  - `enabledPlugins."honcho@honcho" = true`
  - `env`: `HONCHO_ENDPOINT=https://mini.quokka-qilin.ts.net:8100`, `HONCHO_API_KEY=sk-no-auth`, `HONCHO_WORKSPACE=jadee`, `HONCHO_PEER_NAME=jadee`, `HONCHO_AI_PEER=claude`
- `settings.json` is an **out-of-store symlink** → edits go live without a rebuild (plugin enablement + env resolved from the live file; validated: plugin's `loadConfigFromEnv()` resolves `baseURL=…:8100/v3`, workspace `jadee`).
- Auto-injection via Claude's `SessionStart`/`UserPromptSubmit` hooks **+** MCP tools (`search`/`chat`/`create_conclusion`). Honcho itself has **no push/webhook** — injection is Claude's hooks calling Honcho's pull API.
- Per-machine knobs in `~/.honcho/config.json`: `skipDialectic` (skip the per-prompt LLM `chat()` that runs on mini's deriver — relevant for GPU contention), `contextRefresh.messageThreshold` (default 30), `ttlSeconds` (300).
- **Requires `bun`** (provided by the `web` devenv profile — `modules/profiles/devenv/languages/web.nix`; NOT present on hosts without that profile).

### ✅ hermes — committed, evaluates
- `NousResearch/hermes-agent` v0.16.0 ships a **native Honcho memory provider** — no MCP glue.
- `hosts/mini/services/hermes.nix`: `settings.memory.provider = "honcho"`, `extraDependencyGroups = ["honcho"]` (pulls `honcho-ai` into the sealed uv venv → triggers a venv rebuild on switch).
- Identity config (`workspace`/`peerName`/`aiPeer`) has **no env-var fallback** (only `HONCHO_API_KEY`/`HONCHO_BASE_URL`/`HONCHO_ENVIRONMENT` do), so it's carried in `hosts/mini/services/documents/honcho.json`:
  - `baseUrl: http://127.0.0.1:8100` (loopback — hermes runs on mini; local URL auto-skips auth + auto-enables), `workspace: jadee`, `peerName: jadee`, `pinUserPeer: true`, `hosts.hermes.{aiPeer: hermes, recallMode: hybrid, sessionStrategy: per-repo}`.
- The module's `documents` option installs into `workingDirectory`, **not** `HERMES_HOME` (where the provider looks: `$HERMES_HOME/honcho.json` is priority 1). So `honcho.json` is placed via `system.activationScripts.hermes-honcho-config` (ordered after the module's `hermes-agent-setup`) → `/var/lib/hermes/.hermes/honcho.json`. Verified by eval.
- ⚠️ hermes is enabled but still needs its **Phase-2 model/provider** config (e.g. OpenRouter via sops `hermes/env`) to actually run; memory wiring is independent of that.

### ✅ omp (oh-my-pi) — auto-injection hook authored + wired (STAGED, not committed)
- No native pi/omp Honcho plugin exists. The closest-to-native path is a hook mirroring `@honcho-ai/opencode-honcho`.
- `data/agents/omp/hooks/honcho-context.ts` — **dependency-free** hook (bun global `fetch` → `POST /v3/workspaces/jadee/peers/jadee/chat`, the dialectic endpoint). On `before_agent_start` it injects a `<memory-context>` message (`display:false`, so in LLM context but not TUI). **Fail-open**: any error/timeout silently skips injection. Endpoint/identity default to mini+`jadee`, overridable via `HONCHO_ENDPOINT`/`HONCHO_WORKSPACE`/`HONCHO_PEER_NAME`.
- Wired in `modules/profiles/devenv/agents/global-config.nix` as a live-symlink → `~/.omp/agent/hooks/honcho-context.ts` (auto-discovered from omp's hooks dir).
- Verified: `bun build` parses/bundles OK; HM eval produces the symlink.
- **Validate on first run:** `showHookStatus: true` is set in `data/agents/omp/config.yml`, so the statusline shows whether the hook loaded — confirms the `~/.omp/agent/hooks/` auto-discovery assumption (derived from omp `loader.ts`, comment ".omp/.pi hooks/").

---

## Remaining gaps

1. **omp MCP tools — blocked, needs packaging.** The official `@honcho-ai/mcp` is **incompatible** with the self-hosted server: published `@honcho-ai/core@2.2.0` (its SDK) hits `/v2/workspaces` (132 occurrences, verified by unpacking the npm tarball) but the server is v3-only. So `npx @honcho-ai/mcp` would silently 404. The **only v3-compatible MCP** is packaging claude-honcho's `mcp-server.ts` (built on the v3 `@honcho-ai/sdk`, exposes `search`/`chat`/`create_conclusion`) as a Nix/bun package, then adding it to the shared registry.
   - ⚠️ The shared MCP registry `lib/mcp-servers.nix` `availableSharedServers` fans out to **Claude too** (`claude-mcp.nix` runs `claude mcp add-json`). Claude already has `honcho` via the plugin's own MCP server, so adding it to the shared registry **collides**. Scope any honcho MCP entry to pi/omp only (e.g. a separate coding-agent-only server set, not `availableSharedServers`).
2. **omp write-back.** The hook is read-only (injection). omp consumes shared memory but doesn't persist its own turns to Honcho (no session resolution + `add_messages`). omp/Claude/hermes won't learn from omp activity until this is added.

---

## Key reference

- **SDK base URL:** pass the **bare origin** (`https://mini.quokka-qilin.ts.net:8100`, no `/v3`) — `@honcho-ai/sdk` prepends `/v3` itself. (hermes & the omp hook use loopback `http://127.0.0.1:8100`.)
- **Dialectic (synthesized "what we know about X"):** `POST /v3/workspaces/{ws}/peers/{peer}/chat` → `{ content: string }`.
- **Queue status:** `GET /v3/workspaces/{ws}/queue/status`.

## Files
- `hosts/mini/services/honcho.nix` — server env (`honchoEnv` let-binding). Provider keys → optional sops `honcho/env`.
- `hosts/mini/services/hermes.nix` + `hosts/mini/services/documents/honcho.json` — hermes native provider.
- `data/agents/global/settings.json` — Claude Code plugin + env.
- `data/agents/omp/hooks/honcho-context.ts` + `modules/profiles/devenv/agents/global-config.nix` — omp injection hook (staged).
- Planning context: `docs/hosts/mini-agent-memory-plan.md`.

## Suggested skills
- `diagnose` (trace the LLM call path / deriver→local-LLM), `verify` (exercise a query, watch logs + queue), `run`.
