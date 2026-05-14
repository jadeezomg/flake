# Zed agent tool permissions. See: https://zed.dev/docs/ai/tool-permissions
# Full tools list: https://zed.dev/docs/ai/tools#tools
#
# Permission-gatable built-in tools are configured below.
# Other tools (diagnostics, find_path, grep, list_directory, now, open, read_file,
# thinking, spawn_agent) are not in tool_permissions and need no entries.
#
# Policy: global default is "confirm". Read-only/non-intrusive terminal commands are
# auto-approved; anything that modifies state remains confirm unless explicitly allowed.
{
  default = "confirm";

  tools = {
    # Terminal: allow read-only / non-intrusive commands; everything else stays confirm
    terminal = {
      default = "confirm";
      always_allow = [
        # Navigation and listing
        {pattern = "^ls\\b";}
        {pattern = "^cd\\b";}
        {pattern = "^pwd\\b";}
        # Read-only output
        {pattern = "^cat\\s";}
        {pattern = "^echo\\s";}
        {pattern = "^head\\s";}
        {pattern = "^tail\\s";}
        # Shell introspection
        {pattern = "^which\\b";}
        {pattern = "^type\\b";}
        {pattern = "^whence\\b";}
        {pattern = "^env\\b";}
        {pattern = "^printenv\\b";}
        {pattern = "^true\\b";}
        {pattern = "^false\\b";}
        # Read-only git
        {pattern = "^git\\s+(status|log|diff|branch|show|describe)\\b";}
        # Read-only cargo (check/build/test/clippy/fmt — no publish/push)
        {pattern = "^cargo\\s+(check|build|test|clippy|fmt|doc)\\b";}
        # Nushell / common read-only
        {pattern = "^nu\\s+-c\\s+";}
      ];
      # Extra safety: always prompt for sudo and destructive patterns
      always_confirm = [
        {pattern = "sudo\\s";}
        {pattern = "\\brm\\s";}
        {pattern = "\\bmv\\s";}
        {pattern = "\\bcp\\s";}
        {pattern = "git\\s+push";}
        {pattern = "npm\\s+install";}
        {pattern = "cargo\\s+publish";}
      ];
    };

    # All modifying tools: default confirm, no always_allow → user must approve
    edit_file = {default = "confirm";};
    save_file = {default = "confirm";};
    delete_path = {default = "confirm";};
    move_path = {default = "confirm";};
    copy_path = {default = "confirm";};
    create_directory = {default = "confirm";};
    restore_file_from_disk = {default = "confirm";};

    # External access: require approval. Prefer the funnel CLIs documented in
    # data/agents/global/AGENTS.md (kagi-ken-cli, ctx7, context-mode) — they
    # have stable network shape, persistent caching, and known auth.
    fetch = {default = "confirm";};
    search_web = {default = "confirm";};

    # MCP: always allow Context7 documentation tools
    "mcp:mcp-server-context7:resolve-library-id" = {default = "allow";};
    "mcp:mcp-server-context7:get-library-docs" = {default = "allow";};
  };
}
