# Declarative nono profiles installed to ~/.config/nono/profiles/. Resolved
# by name from `nono run --profile <name>`, so the same profile works from
# the Zed agent_servers entries (agents-and-mcp.nix) and the devShells in
# parts/shells.nix.
{
  lib,
  osConfig,
  ...
}: let
  agentsEnabled = osConfig.dotfiles.profiles.devenv.llm.agents.enable or false;

  profiles = {
    # claude-code with the same egress allowlist enforced by the bwrap-based
    # claude-sandbox devShell. Filesystem rules inherited from `claude-code`
    # (which already grants ~/.claude, ~/.claude.json, $WORKDIR rw).
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

    # pi extends `default` (no built-in pi profile) and grants the paths pi
    # actually writes: ~/.pi/agent state, ~/.npm-global (NPM_CONFIG_PREFIX
    # set by the pi wrapper in packages/pi-coding-agent), and ~/.npm cache.
    # Network is intentionally left open — pi routes to multiple LLM
    # providers; tighten with --allow-domain after observing real traffic.
    pi-flake = {
      meta = {
        name = "pi-flake";
        version = "1.0.0";
        description = "pi coding agent, FS-sandboxed, open egress";
      };
      extends = "default";
      filesystem = {
        allow = [
          "$HOME/.pi"
          "$HOME/.npm-global"
          "$HOME/.npm"
        ];
      };
    };
  };

  mkProfileFile = name: data: {
    name = "nono/profiles/${name}.json";
    value = {
      text = builtins.toJSON data;
    };
  };
in
  lib.mkIf agentsEnabled {
    xdg.configFile = lib.mapAttrs' mkProfileFile profiles;
  }
