# `context_servers` (MCP for Zed's own agent panel) is deliberately absent.
# APM owns MCP now and has no Zed target; the ACP agents below read their own
# configs, so claude and omp still reach every server through ~/.claude.json.
_: {
  agent_servers = {
    # rohan-patra fork of the Claude Agent SDK ACP adapter (diff preview
    # support); packaged in numtide/llm-agents.nix.
    claude = {
      type = "custom";
      command = "claude-agent-acp";
      args = [ ];
    };

    # Same adapter inside the claude-flake nono profile (installed by
    # nono-profiles.nix; grants ~/.claude via the claude-code base pack).
    # Permission mode stays switchable per-session in Zed's UI — the adapter
    # reads permissions.defaultMode from Claude settings, not a CLI flag.
    claude-nono = {
      type = "custom";
      command = "nono";
      args = [
        "run"
        "--profile"
        "claude-flake"
        "--allow-cwd"
        "--rollback"
        "--no-rollback-prompt"
        "--name"
        "claude-zed"
        "--"
        "claude-agent-acp"
      ];
    };

    pi = {
      type = "registry";
      favorite_models = [
        "openrouter/~anthropic/claude-opus-latest"
        "openrouter/moonshotai/kimi-k2.6"
      ];
    };

    # FS-isolated to ~/.pi, ~/.npm*, and the cwd. Network open until tightened
    # via --allow-domain. Profile comes from the `nono-pi` devShell.
    pi-nono = {
      type = "custom";
      command = "nono";
      args = [
        "run"
        "--profile"
        "pi-flake"
        "--allow-cwd"
        "--rollback"
        "--no-rollback-prompt"
        "--name"
        "pi-zed"
        "--"
        "npx"
        "-y"
        "pi-acp"
      ];
      env = {
        "PI_ACP_ENABLE_EMBEDDED_CONTEXT" = "true";
      };
    };

    # omp ships ACP directly via `--mode acp`; no pi-acp adapter needed.
    omp = {
      type = "custom";
      command = "omp";
      args = [
        "--mode"
        "acp"
      ];
    };

    # Uses the omp-flake nono profile installed by nono-profiles.nix.
    omp-nono = {
      type = "custom";
      command = "nono";
      args = [
        "run"
        "--profile"
        "omp-flake"
        "--allow-cwd"
        "--rollback"
        "--no-rollback-prompt"
        "--name"
        "omp-zed"
        "--"
        "omp"
        "--mode"
        "acp"
      ];
    };
  };

  agent = {
    thinking_display = "always_collapsed";
    play_sound_when_agent_done = "always";
    expand_edit_card = true;
    notify_when_agent_waiting = "never";
    single_file_review = true;
    model_parameters = [ ];
    tool_permissions = import ../tool-permissions.nix;
    show_turn_stats = true;
  };
}
