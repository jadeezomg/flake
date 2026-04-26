{claude-agent-acp-fork}: {
  # --- External Agents ---
  agent_servers = {
    # --- Registry ---
    pi-acp = {
      type = "registry";
    };
    claude-acp = {
      type = "registry";
    };

    # --- Pi ---
    pi = {
      type = "custom";
      command = "npx";
      args = ["-y" "pi-acp"];
      env = {
        "PI_ACP_ENABLE_EMBEDDED_CONTEXT" = "true";
      };
    };

    # --- Claude Agent ACP Fork with inline accept/reject---
    claude-agent-acp-fork = {
      type = "custom";
      command = "${claude-agent-acp-fork}/bin/claude-agent-acp";
      args = [];
    };
  };

  context_servers = {
    mcp-server-context7 = {
      enabled = true;
      remote = false;
    };
    mcp-server-github = {
      enabled = true;
      remote = false;
    };
    code-review-graph = {
      command = "uvx";
      args = [
        "code-review-graph"
        "serve"
      ];
    };
  };

  # --- Agent ---
  agent = {
    thinking_display = "always_collapsed";
    play_sound_when_agent_done = "when_hidden";
    expand_edit_card = true;
    notify_when_agent_waiting = "never";
    single_file_review = true;
    model_parameters = [];
    tool_permissions = import ../tool-permissions.nix;
    show_turn_stats = true;
  };
}
