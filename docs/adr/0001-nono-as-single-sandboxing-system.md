# 0001 — Nono as the single agent sandboxing system

**Status:** accepted

We unify the previously parallel `nono` and `agent-sandbox.nix` paths onto **nono** as the sole sandboxing layer for coding agents (Claude Code, pi). nono won on three criteria: (1) it composes via `extends` and policy groups, so adding a third agent is small and the two existing profiles stay in lockstep; (2) its native HTTPS broker (reverse proxy with header injection) lets us avoid LLM/git API keys in the sandbox env, satisfying the "broker over passthrough" principle; (3) it integrates with libsecret/secret-service, the de-facto Linux credential standard. `agent-sandbox.nix` is removed in the same change — flake input dropped, `claude-sandbox` devShell deleted.

## Coupled decisions

**Broker-mode credentials via libsecret.** OpenRouter, Context7, and GitHub credentials are loaded from sops into the gnome-keyring (libsecret) at home-manager activation by `home/shared/shells/sops-keyring.nix`. Profiles reference them via `keyring://nono/<account>` URIs; nono's reverse proxy injects them as headers on outbound requests, so the sandbox env never sees the value.

**Per-agent git identity with co-author trailer.** Each agent gets its own author/committer identity (`claude-jadee <claude@jadee.fyi>`, `pi-jadee <pi@jadee.fyi>`) via `GIT_AUTHOR_*` / `GIT_COMMITTER_*` env vars set in the agent profile. A flake-built `prepare-commit-msg` hook (referenced via `GIT_CONFIG_GLOBAL` → `core.hooksPath`) appends `Co-Authored-By: jadeezomg <github@jadee.fyi>` to every commit, idempotently via `git interpret-trailers --if-exists doNothing`. The host's `~/.gitconfig` remains visible inside the sandbox via the inherited `git_config` policy group; env vars override identity at git's resolution layer, so leaked aliases are not a security concern.

**Profile composition pattern.** Agent profiles are emitted by a single `mkAgentProfile` Nix helper in `lib/nono-profiles.nix`, parameterized by name, base profiles, agent-specific filesystem paths, git identity, and extra credentials. nono itself sees only the materialized child profiles (`claude-flake`, `pi-flake`); the shared base lives at the Nix layer. This keeps nono's profile surface minimal while ensuring the two agents stay in lockstep.

**Capability surface.** Both profiles grant the rootless podman socket (`$XDG_RUNTIME_DIR/podman/podman.sock`), `port_localhost` for host-service access, container spawn (`podman` CLI usable), and open egress. Filesystem stays explicit — only the agent's own dot-dirs are writable beyond the workdir. Claude Code is invoked with `--dangerously-skip-permissions` because nono is now the security boundary; Claude's internal permission prompts become friction.

## Out of scope / future work

1. **Per-tool human-CLI wrappers.** The "every credential-using process gets its own scoped sandbox" model extends naturally to human-invoked CLIs (`kagi-ken-cli`, `ctx7`). Deferred: define `kagi-cli-flake` and `ctx7-cli-flake` profiles, ship `mkSandboxedCli` shims via home-manager so they shadow the bare CLIs on `PATH`, then remove the corresponding entries from `sops-session-env.nix`. Until that lands, the human runs those CLIs unsandboxed and they read keys from session env (status quo).

2. **Anthropic OAuth → broker promotion.** Claude Code persists its OAuth credentials in `~/.claude/.credentials.json` (a `stateDirs`-bound file inside the sandbox), so the `anthropic` broker is decorative for Claude until empirically tested. Test: write a custom `anthropic-oauth` credential definition with `Authorization: Bearer {}`, drop the credentials file from `stateDirs`, and verify Claude Code starts and authenticates. If yes — promote. If no — keep the file and document the asterisk.

3. **Kagi cookie-injection broker.** Kagi (via `kagi-ken-cli`) authenticates with a session-token cookie, not a Bearer header. Test: nono's `inject_mode: header` with `inject_header: Cookie` and `credential_format: kagisid={}` against `kagi.com`. If injection works, kagi joins the keyring and `kagi-cli-flake` is broker-only; if not, fall back to a scoped env-credential (`--env-credential kagi_api_key`) inside the tool profile, never in the user's session env. Tied to item 1.

4. **`sops-session-env.nix` → `sops-keyring.nix` Phase 2.** As tool wrappers land (item 1), the corresponding sops entries migrate from session-env exports to keyring-only entries. Goal state: `sops-session-env.nix` carries only non-credential env vars (locale, paths). `OPENROUTER_API_KEY`, `CONTEXT7_API_KEY`, `KAGI_API_KEY`, and the GitHub agent PAT continue to be exported in session env in Phase 1.

5. **`mini` host integration.** The headless server has no user session and therefore no libsecret keyring daemon. If we later run agents on `mini` (unattended overnight workflows, scheduled runs), the credential pipeline needs an alternative — `pass-secret-service`, a system-level secret store, or sops-decrypted-at-runtime files. Not on the roadmap.
