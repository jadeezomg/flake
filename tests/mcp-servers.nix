{ lib }:
let
  registry = import ../lib/mcp-servers.nix { inherit lib; };

  disabledRegistry = import ../lib/mcp-servers.nix {
    inherit lib;
    osConfig.dotfiles.profiles.devenv.agents.enable = false;
  };

  activation = registry.mkMcpJsonMergeActivation {
    mcpDir = "/tmp/mcp-test";
    mcpFile = "/tmp/mcp-test/mcp.json";
  };

  disabledActivation = disabledRegistry.mkMcpJsonMergeActivation {
    mcpDir = "/tmp/mcp-disabled-test";
    mcpFile = "/tmp/mcp-disabled-test/mcp.json";
  };

  zedActivation = registry.mkZedObsoleteRemovalActivation {
    settingsFile = "/tmp/zed/settings.json";
    configDir = "/tmp/zed";
  };

  cursorActivation = registry.mkCursorObsoleteRemovalActivation {
    mcpFile = "/tmp/cursor/mcp.json";
    cliConfigFile = "/tmp/cursor/cli-config.json";
  };

  claudeFileActivation = registry.mkClaudeObsoleteFileRemovalActivation "/tmp/home";
  npmActivation = registry.mkNpmGlobalObsoleteRemovalActivation "/tmp/home";

  cleanupActivations = lib.concatStrings [
    registry.mkClaudeObsoleteRemovalActivation
    registry.mkClaudeObsoletePluginRemovalActivation
    registry.mkOmpObsoletePluginRemovalActivation
    claudeFileActivation
    npmActivation
    zedActivation
  ];

  claudeModuleSource = builtins.readFile ../modules/profiles/devenv/agents/claude-mcp.nix;

  disabledAgentsModule = lib.evalModules {
    specialArgs = {
      dotfilesLib.nonoProfiles = _: {
        agentPackages = [ ];
      };
      pkgs = { };
      pkgs-small = { };
    };
    modules = [
      (
        { lib, ... }:
        {
          options = {
            dotfiles.profiles.devenv.agents.enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
            };
            home-manager.sharedModules = lib.mkOption {
              type = lib.types.listOf lib.types.raw;
              default = [ ];
            };
            environment.systemPackages = lib.mkOption {
              type = lib.types.listOf lib.types.raw;
              default = [ ];
            };
          };
        }
      )
      ../modules/profiles/devenv/agents/default.nix
    ];
  };

  disabledAgentSharedModules = disabledAgentsModule.config.home-manager.sharedModules;
in
assert registry.needsSharedServerMaintenance;
assert builtins.elem "context-mode" registry.obsoleteSharedServers;
assert builtins.elem "context-mode@context-mode" registry.obsoleteClaudePlugins;
assert builtins.elem "context-mode" registry.obsoleteClaudeMarketplaces;
assert builtins.elem ".claude/hooks/context-mode-cache-heal.mjs" registry.obsoleteClaudeFiles;
assert builtins.elem "context-mode" registry.obsoleteOmpPlugins;
assert builtins.elem "context-mode" registry.obsoleteNpmGlobalPackages;
assert lib.hasInfix "claude mcp remove --scope user context-mode"
  registry.mkClaudeObsoleteRemovalActivation;
assert lib.hasInfix "claude plugin uninstall --scope user -y --prune context-mode@context-mode"
  registry.mkClaudeObsoletePluginRemovalActivation;
assert lib.hasInfix "claude plugin marketplace remove --scope user context-mode"
  registry.mkClaudeObsoletePluginRemovalActivation;
assert
  !(lib.hasInfix "claude plugin marketplace remove context-mode" registry.mkClaudeObsoletePluginRemovalActivation);
assert lib.hasInfix "if command_output=$(claude plugin uninstall"
  registry.mkClaudeObsoletePluginRemovalActivation;
assert !(lib.hasInfix "2>&1 | sed" cleanupActivations);
assert lib.hasInfix "if command_output=$(claude mcp add-json" claudeModuleSource;
assert lib.hasInfix "gio trash \"$obsolete_file\"" claudeFileActivation;
assert lib.hasInfix "omp plugin uninstall context-mode"
  registry.mkOmpObsoletePluginRemovalActivation;
assert lib.hasInfix "npm uninstall -g --prefix" npmActivation;
assert lib.hasInfix "del(.context_servers[$name])" zedActivation;
assert lib.hasInfix "gio trash" zedActivation;
assert lib.hasInfix "del(.mcpServers[$name])" cursorActivation;
assert lib.hasInfix "startswith(\"Mcp(\" + $name + \":\")" cursorActivation;
assert disabledRegistry.sharedServers == { };
assert disabledRegistry.needsSharedServerMaintenance;
assert lib.hasInfix "del(.mcpServers[$name])" disabledActivation;
assert !(lib.hasInfix "mcp-nixos" disabledActivation);
assert builtins.elem ../modules/profiles/devenv/agents/pi-mcp.nix disabledAgentSharedModules;
assert builtins.elem ../modules/profiles/devenv/agents/omp-mcp.nix disabledAgentSharedModules;
assert builtins.elem ../modules/profiles/devenv/agents/claude-mcp.nix disabledAgentSharedModules;
assert builtins.elem ../modules/profiles/devenv/agents/mcp-obsolete-npm.nix
  disabledAgentSharedModules;
assert lib.hasInfix "del(.mcpServers[$name])" activation;
true
