{claude-agent-acp-fork}: let
  sharedMcpServers = import ../../../../development/tooling/mcp-servers.nix;
in {
  # --- External Agents ---
  agent_servers = {
    # --- Registry ---
    claude-acp = {
      type = "registry";
    };
    goose = {
      type = "registry";
    };
    cursor = {
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

    # --- Pi (sandboxed via nono) ---
    # FS-isolated to ~/.pi, ~/.npm*, and the cwd. Network open until tightened
    # via --allow-domain. Profile lives in parts/shells.nix (`nono-pi` devShell)
    # — drop a copy at ~/.config/nono/profiles/pi-flake.json or reference the
    # store path printed by `nix develop .#nono-pi`.
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

    # --- Claude Agent ACP Fork with inline accept/reject---
    claude-agent-acp-fork = {
      type = "custom";
      command = "${claude-agent-acp-fork}/bin/claude-agent-acp";
      args = [];
    };
  };

  context_servers =
    {
      mcp-server-context7 = {
        settings = {};
        enabled = true;
        remote = false;
      };
      mcp-server-github = {
        settings = {};
        enabled = true;
        remote = false;
      };
    }
    // sharedMcpServers;

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
