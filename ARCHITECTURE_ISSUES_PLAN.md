# Architecture Deepening Issue Plan

## Context

This plan breaks the architecture review into independently-grabbable tracer-bullet issues. Each slice is narrow but complete enough to verify on its own. The vocabulary follows the project domain model: Sandbox, Agent, Agent profile, Broker, Credential, Dispatcher, Agent identity, Co-author trailer, Host service, Container.

## Proposed slices

### 1. Deepen Agent package ownership from Agent metadata

**Type:** AFK  
**Blocked by:** None

## What to build

Make the Agent metadata in `lib/nono-profiles.nix` the source of truth for the Agent package set, so the system package list cannot drift from the Agent profiles and Dispatcher.

## Acceptance criteria

- [ ] Agent packages used by `modules/shared/profiles/devenv/llm/agents.nix` are derived from Agent metadata or validated against it.
- [ ] Adding a new Agent metadata entry has a clear failure if the Agent package is not installed.
- [ ] A focused eval/test proves Claude, pi, and omp remain installed when Agent profiles are enabled.

## Blocked by

None - can start immediately

---

### 2. Deepen Agent invocation locality for Dispatcher and devShells

**Type:** AFK  
**Blocked by:** None

## What to build

Centralize the nono invocation Implementation used by the Dispatcher and devShells so Agent identity, Co-author trailer wiring, profile path, rollback flags, and Agent args have one owner.

## Acceptance criteria

- [ ] Dispatcher invocation and devShell invocation are generated from the same Module.
- [ ] Agent identity and `GIT_CONFIG_GLOBAL` are not duplicated across `lib/nono-profiles.nix` and `parts/shells.nix`.
- [ ] A focused eval/test proves generated invocations for Claude and pi include the expected Agent identity and profile.

## Blocked by

None - can start immediately

---

### 3. Decide Agent identity Seam in nono profiles

**Type:** HITL  
**Blocked by:** None

## What to build

Decide whether Agent identity should remain invocation-owned or move into the Agent profile when nono supports profile-level env. Record the decision before changing the long-term Seam.

## Acceptance criteria

- [ ] Current nono profile capabilities are verified from local docs or tool behavior.
- [ ] The chosen Agent identity Seam is documented in the relevant ADR or context file.
- [ ] The decision explains how bare `nono run --profile ...` should behave for Agent identity and Co-author trailer wiring.

## Blocked by

None - can start immediately

---

### 4. Deepen MCP registration across Claude, pi, and omp

**Type:** AFK  
**Blocked by:** None

## What to build

Replace duplicated MCP activation logic with one MCP registration Module that owns enablement, shared server declarations, per-Agent paths, and idempotent merge behavior.

## Acceptance criteria

- [ ] Claude, pi, and omp MCP registration flows use one shared registration path with per-Agent data.
- [ ] The `agentsEnabled` guard is declared once or verified once.
- [ ] Focused tests or eval checks prove all three Agent adapters receive the shared MCP servers.

## Blocked by

None - can start immediately

---

### 5. Deepen Zed MCP Adapter validation

**Type:** AFK  
**Blocked by:** 4

## What to build

Add a Zed MCP Adapter that transforms shared MCP server declarations into Zed `context_servers` shape and validates extension-managed entries and shared entries together.

## Acceptance criteria

- [ ] Shared MCP server entries are transformed into valid Zed `context_servers` entries.
- [ ] Collisions between shared MCP servers and extension-managed MCP servers fail at evaluation with a clear message.
- [ ] A focused eval/test proves every Zed context server has required Zed fields.

## Blocked by

- Slice 4: Deepen MCP registration across Claude, pi, and omp

---

### 6. Decide MCP Credential ownership before Tool profiles

**Type:** HITL  
**Blocked by:** 4

## What to build

Decide where MCP server Credential requirements should live before future Tool profiles are introduced, so the Broker and MCP registry do not grow separate sources of truth.

## Acceptance criteria

- [ ] Current MCP servers and their Credential needs are documented.
- [ ] The chosen ownership model states whether Credential declarations live with Agent profiles, MCP server declarations, or a shared registry.
- [ ] Any ADR-0001 follow-up is recorded if the decision changes future Tool profile work.

## Blocked by

- Slice 4: Deepen MCP registration across Claude, pi, and omp

---

### 7. Deepen Host Status snapshot for one visible path

**Type:** AFK  
**Blocked by:** None

## What to build

Create a Host Status Interface that emits one serializable snapshot for at least one visible path, proving the status Module can be tested through its Interface rather than through shell output alone.

## Acceptance criteria

- [ ] `host-status` can emit a structured snapshot for a narrow set of Host facts.
- [ ] Existing one-line output remains available for current callers.
- [ ] Tests cover success, missing data, and malformed data for the first structured Host Status path.

## Blocked by

None - can start immediately

---

### 8. Deepen Host Status Credential cache declarations

**Type:** AFK  
**Blocked by:** 7

## What to build

Declare Credential-backed Host Status cache sources in one Nix-level Module so cache paths, Credential lookup, refresh cadence, and reader expectations stay aligned.

## Acceptance criteria

- [ ] OpenRouter and Claude cache declarations are represented in one shared cache declaration Module.
- [ ] Linux systemd timers and Darwin launchd agents are generated from that declaration.
- [ ] Tests or eval checks prove each declared cache source has a refresher and a reader.

## Blocked by

- Slice 7: Deepen Host Status snapshot for one visible path

---

### 9. Route health output through Host Status Interface

**Type:** AFK  
**Blocked by:** 7

## What to build

Make the human-facing health path render from the Host Status Interface so `just health`, fastfetch, and `host-status all` stop being independent partial Implementations.

## Acceptance criteria

- [ ] At least one existing health display path renders from the structured Host Status snapshot.
- [ ] Differences between health displays are explicit Adapter choices, not duplicated status logic.
- [ ] A focused test compares rendered output against a fixed Host Status snapshot.

## Blocked by

- Slice 7: Deepen Host Status snapshot for one visible path

---

### 10. Validate package update metadata before network work

**Type:** AFK  
**Blocked by:** None

## What to build

Add validation for `update.json` metadata before package update handlers perform network work or rewrite Nix files.

## Acceptance criteria

- [ ] Invalid handler type, missing hash fields, and missing default Nix attributes fail before network calls.
- [ ] Validation errors name the package and the exact broken field.
- [ ] Unit tests cover valid and invalid metadata for at least `binary_channel`, `npm`, and `github_npm` packages.

## Blocked by

None - can start immediately

---

### 11. Deepen oh-my-pi release platform mapping

**Type:** AFK  
**Blocked by:** 10

## What to build

Make the `oh-my-pi` multi-platform binary release mapping one coherent Module so Nix systems, upstream assets, and hash field names cannot drift independently.

## Acceptance criteria

- [ ] `x86_64-linux` and `aarch64-darwin` mappings are validated against update metadata.
- [ ] Unsupported systems still fail clearly at Nix evaluation.
- [ ] A focused test proves `update.json` platform fields match `default.nix` platform/hash declarations.

## Blocked by

- Slice 10: Validate package update metadata before network work

---

### 12. Deepen package update handler lifecycle tests

**Type:** AFK  
**Blocked by:** 10

## What to build

Separate package update orchestration from handler-specific fetch logic enough to test cooldown, drift detection, rewrite behavior, and error reporting without relying on live upstream calls.

## Acceptance criteria

- [ ] Cooldown handling is tested independently of package handler network behavior.
- [ ] Hash drift detection is tested with fixed file fixtures.
- [ ] Handler lifecycle tests cover no-op, version change, field-only change, and rewrite failure.

## Blocked by

- Slice 10: Validate package update metadata before network work

---

### 13. Validate Host records at flake evaluation

**Type:** AFK  
**Blocked by:** None

## What to build

Introduce Host record validation so required Host facts and optional Host facts are explicit at flake evaluation rather than hidden behind `or` defaults.

## Acceptance criteria

- [ ] Host records validate required fields such as hostname/system/user/stateVersion.
- [ ] Missing required Host facts fail with messages naming the Host and field.
- [ ] Focused eval checks prove existing hosts pass validation.

## Blocked by

None - can start immediately

---

### 14. Validate Host class profile compatibility

**Type:** AFK  
**Blocked by:** 13

## What to build

Declare Host class semantics and validate profile compatibility so desktop-only and server-only assumptions are enforced by the Host topology Module.

## Acceptance criteria

- [ ] Host records declare enough class/profile facts to validate profile compatibility.
- [ ] A server Host cannot silently accept desktop-only profile assumptions.
- [ ] A focused eval/test covers valid desktop, valid server, and invalid profile combinations.

## Blocked by

- Slice 13: Validate Host records at flake evaluation

---

### 15. Decide Host profile routing ownership

**Type:** HITL  
**Blocked by:** 13, 14

## What to build

Decide whether per-Host profile selection should remain in `hosts/*/profiles.nix` or route through one Host topology Module after Host validation exists.

## Acceptance criteria

- [ ] Existing profile selection behavior is mapped for desktop, framework, mini, and caya.
- [ ] The chosen ownership model states where profile rules live and how Host class rules are enforced.
- [ ] The decision is recorded if it prevents future architecture reviews from re-suggesting the rejected path.

## Blocked by

- Slice 13: Validate Host records at flake evaluation
- Slice 14: Validate Host class profile compatibility
