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

  claudeModuleSource = builtins.readFile ../modules/profiles/devenv/agents/claude-mcp.nix;

  enabledAgentsModule = lib.evalModules {
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
              default = true;
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

  enabledAgentSharedModules = enabledAgentsModule.config.home-manager.sharedModules;
  disabledAgentSharedModules = disabledAgentsModule.config.home-manager.sharedModules;
in
assert registry.needsSharedServerMaintenance;
assert builtins.hasAttr "mcp-nixos" registry.sharedServers;
assert !(builtins.hasAttr "mcp-nixos" disabledRegistry.sharedServers);
assert disabledRegistry.sharedServers == { };
assert !disabledRegistry.needsSharedServerMaintenance;
assert !(lib.hasInfix "del(.mcpServers[$name])" activation);
assert lib.hasInfix ".mcpServers[$e.key]" activation;
assert lib.hasInfix "mcp-nixos" activation;
assert !(lib.hasInfix "mcp-nixos" disabledActivation);
assert lib.hasInfix "if command_output=$(claude mcp add-json" claudeModuleSource;
assert !(lib.hasInfix "claude mcp remove" claudeModuleSource);
assert builtins.elem ../modules/profiles/devenv/agents/pi-mcp.nix enabledAgentSharedModules;
assert builtins.elem ../modules/profiles/devenv/agents/omp-mcp.nix enabledAgentSharedModules;
assert builtins.elem ../modules/profiles/devenv/agents/claude-mcp.nix enabledAgentSharedModules;
assert !(builtins.elem ../modules/profiles/devenv/agents/pi-mcp.nix disabledAgentSharedModules);
assert disabledAgentSharedModules == [ ];
true
