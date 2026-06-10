{lib}: let
  registry = import ../home/shared/development/tooling/mcp-servers.nix {inherit lib;};

  disabledRegistry = import ../home/shared/development/tooling/mcp-servers.nix {
    inherit lib;
    osConfig.dotfiles.profiles.devenv.llm.agents.enable = false;
  };

  activation = registry.mkMcpJsonMergeActivation {
    mcpDir = "/tmp/mcp-test";
    mcpFile = "/tmp/mcp-test/mcp.json";
  };

  disabledActivation = disabledRegistry.mkMcpJsonMergeActivation {
    mcpDir = "/tmp/mcp-disabled-test";
    mcpFile = "/tmp/mcp-disabled-test/mcp.json";
  };
in
  assert registry.needsSharedServerMaintenance;
  assert builtins.elem "context-mode" registry.obsoleteSharedServers;
  assert lib.hasInfix "claude mcp remove --scope user context-mode"
  registry.mkClaudeObsoleteRemovalActivation;
  assert disabledRegistry.sharedServers == {};
  assert disabledRegistry.needsSharedServerMaintenance;
  assert lib.hasInfix "del(.mcpServers[$name])" disabledActivation;
  assert !(lib.hasInfix "mcp-nixos" disabledActivation);
  assert lib.hasInfix "del(.mcpServers[$name])" activation; true
