{claude-agent-acp-fork}: let
  registryLib = rec {
    attrNames = builtins.attrNames;
    concatStringsSep = builtins.concatStringsSep;
    mapAttrs = f: attrs:
      builtins.listToAttrs (map (name: {
          inherit name;
          value = f name attrs.${name};
        })
        (attrNames attrs));
    intersectLists = left: right: builtins.filter (name: builtins.elem name right) left;
    assertMsg = condition: message:
      if condition
      then true
      else builtins.throw message;
  };
  mcpRegistry = import ../../../../development/tooling/mcp-servers.nix {lib = registryLib;};
  extensionManagedMcpServers = {
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
  };
in {
  agent_servers = {
    claude-acp = {
      type = "registry";
    };
    goose = {
      type = "registry";
    };
    cursor = {
      type = "registry";
    };

    pi = {
      type = "custom";
      command = "npx";
      args = ["-y" "pi-acp"];
      env = {
        "PI_ACP_ENABLE_EMBEDDED_CONTEXT" = "true";
      };
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
      args = ["--mode" "acp"];
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

    claude-agent-acp-fork = {
      type = "custom";
      command = "${claude-agent-acp-fork}/bin/claude-agent-acp";
      args = [];
    };
  };

  context_servers = mcpRegistry.toZedContextServers extensionManagedMcpServers;

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
