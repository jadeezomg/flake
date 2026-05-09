# Single source of truth for nono profile JSON. Consumed by:
#
#   home/shared/development/tooling/nono-profiles.nix
#     installs each as ~/.config/nono/profiles/<name>.json (xdg.configFile)
#     so `nono run --profile <name>` resolves them
#
#   parts/shells.nix
#     renders each via pkgs.writeText for the nono-claude / nono-pi devShells
#     (self-contained; works without a home-manager switch)
#
# Profile authoring guide: `nono profile guide`. Schema: `nono profile schema`.
{
  # claude-code with the same egress allowlist enforced by the bwrap-based
  # claude-sandbox devShell. Filesystem rules and workdir grant inherited
  # from the built-in `claude-code` profile (it grants ~/.claude, ~/.claude.json,
  # $WORKDIR rw, plus nix_runtime / node_runtime groups for NixOS).
  claude-flake = {
    meta = {
      name = "claude-flake";
      version = "1.0.0";
      description = "claude-code base, project egress allowlist";
    };
    extends = "claude-code";
    network = {
      allow_domain = [
        "api.anthropic.com"
        "claude.com"
        "statsig.anthropic.com"
        "api.github.com"
        "raw.githubusercontent.com"
        "objects.githubusercontent.com"
        "registry.npmjs.org"
      ];
    };
  };

  # pi has no built-in nono profile, so we compose one. Extends `linux-host-compat`
  # for the NixOS runtime baseline (sysfs, /run state, system_read groups), then
  # opts into:
  #   nix_runtime  → /run/current-system/sw/bin, /etc/profiles/per-user/...,
  #                  /nix/store reads (npx / node / etc. in PATH)
  #   node_runtime → npm/npx caches and binary lookup paths
  #   git_config   → ~/.gitconfig + git system config (agent commits)
  #
  # User-state paths pi writes:
  #   ~/.pi/agent state, ~/.npm-global (NPM_CONFIG_PREFIX set by the wrapper
  #   in packages/pi-coding-agent), ~/.npm cache, ~/.claude/context-mode
  #   (context-mode MCP stores its index there).
  #
  # workdir.access is set explicitly because linux-host-compat inherits "none"
  # and --allow-cwd doesn't reliably override it for sub-processes.
  #
  # Network intentionally left open — pi routes to multiple LLM providers;
  # tighten with --allow-domain after observing real traffic.
  pi-flake = {
    meta = {
      name = "pi-flake";
      version = "1.0.0";
      description = "pi coding agent, FS-sandboxed, open egress";
    };
    extends = "linux-host-compat";
    security = {
      groups = [
        "nix_runtime"
        "node_runtime"
        "git_config"
      ];
    };
    filesystem = {
      allow = [
        "$HOME/.pi"
        "$HOME/.npm-global"
        "$HOME/.npm"
        "$HOME/.claude/context-mode"
      ];
    };
    workdir = {
      access = "readwrite";
    };
  };
}
