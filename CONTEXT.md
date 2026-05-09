# Agent Sandboxing

The terminology used when configuring sandboxing for coding agents (Claude Code, pi-coding-agent) and the human-invoked CLIs they share secrets with. This file disambiguates words that are otherwise easy to overload.

## Language

**Sandbox**:
A bwrap (Linux) or sandbox-exec (Darwin) jail managed by nono around an agent or tool process.
_Avoid_: "container" (means something different here)

**Container**:
A podman-managed OCI container running on the host, outside any sandbox. Agents reach containers via the rootless podman socket and host loopback.
_Avoid_: "sandbox" (a different isolation primitive)

**Host service**:
A CLI or daemon listening on the host's loopback (e.g. a dev server on `localhost:3000`). Reachable from inside a sandbox when the profile grants `port_localhost`.

**Agent**:
A long-running CLI that orchestrates LLM calls and shells out to host tools. Currently `claude` (Claude Code) and `pi` (`@earendil-works/pi-coding-agent`).
_Avoid_: "bot", "assistant"

**Agent profile**:
A nono profile defining the sandbox capabilities for one agent. Materialized by `mkAgentProfile` in `lib/nono-profiles.nix`. Currently `claude-flake` and `pi-flake`.
_Avoid_: "agent config" (overloaded with the agent's own runtime settings)

**Tool profile** (deferred):
A nono profile wrapping a single human-invoked CLI (`kagi-ken-cli`, `ctx7`) with only the credential it needs. Tracked as future work in ADR-0001; today these CLIs run unsandboxed and read keys from session env.
_Avoid_: "CLI sandbox"

**Broker**:
nono's local HTTPS reverse proxy. Intercepts the sandbox's outbound HTTPS calls and injects credentials per-route, so the sandbox env never sees the value.
_Avoid_: "proxy" (ambiguous with HTTP forward proxy)

**Credential**:
A named secret in the platform keystore — libsecret on Linux, 1Password vault on Darwin — and referenced in agent profiles via `mkCredentialKey`, which emits the bare account name on Linux and an `op://Personal/<account>/credential` URI on Darwin. Loaded from sops into the platform keystore at home-manager activation (`sops-keyring.nix` / `sops-1password.nix`). Distinct from a sops "secret" (the encrypted YAML entry — the source).
_Avoid_: "key", "token" (those refer to the value; credential refers to the named entry)

**Dispatcher**:
The `agent` shell binary on PATH. Subcommands: `agent <name>` runs an agent; `agent ps` / `agent attach` / `agent stop` forward to nono session management; `agent doctor` runs setup health checks. Built once in `lib/nono-profiles.nix` and installed via `home/shared/development/tooling/agents-cli.nix`.

**Agent identity**:
A per-agent git author/committer identity injected via `GIT_AUTHOR_*` / `GIT_COMMITTER_*` env vars in the sandbox. Today: `claude-jadee <claude@jadee.fyi>` and `pi-jadee <pi@jadee.fyi>`. Distinct from the **co-author trailer**.

**Co-author trailer**:
A `Co-Authored-By: jadeezomg <github@jadee.fyi>` line appended to every agent commit by a `prepare-commit-msg` hook. Attributes contributions to the human user on GitHub regardless of which agent authored.

## Relationships

- An **Agent** runs inside a **Sandbox** governed by an **Agent profile**.
- An **Agent profile** declares **Credentials** that the **Broker** injects on outbound HTTPS.
- An **Agent identity** lives in the env block of an **Agent profile**; every agent commit also carries the **Co-author trailer** pointing at the human.
- A **Sandbox** can reach **Containers** via the rootless podman socket and **Host services** on loopback, but is otherwise isolated from them.
- A **Credential** is sourced from sops, materialized into libsecret at HM activation, and read at runtime by the **Broker**.

## Example dialogue

> **Dev:** "Can the agent talk to the Postgres **container** running on `localhost:5432`?"
> **Domain expert:** "Yes — the agent profile grants `port_localhost` and the rootless podman socket. The agent isn't *inside* a container; it's in a **sandbox** on the host that can reach containers via host loopback."

> **Dev:** "If the OpenRouter key is in libsecret, how does pi see it?"
> **Domain expert:** "It doesn't. The **broker** injects `Authorization: Bearer <key>` on outbound requests to `openrouter.ai`. Pi's env has `OPENROUTER_API_KEY` set to a placeholder; the real value never enters the sandbox."

## Flagged ambiguities

- "container" was used early in the design to mean both the **Sandbox** and a podman **Container** — resolved: distinct isolation primitives. nono governs the sandbox; podman manages containers.
- "permissive" was used to describe both filesystem and network policy — resolved: "permissive defaults" applies to network (open egress, broad loopback) and to the `linux-host-compat` baseline; filesystem stays explicit (only listed paths writable).
