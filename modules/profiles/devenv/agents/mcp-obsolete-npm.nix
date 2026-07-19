# npm-global leftovers for obsolete MCP packages (e.g. context-mode installed
# outside the flake before the shared-registry removal).
{
  dotfilesLib,
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  mcpRegistry = dotfilesLib.mcpServers { inherit lib osConfig; };
  inherit (mcpRegistry) needsSharedServerMaintenance mkNpmGlobalObsoleteRemovalActivation;
  homeDir = config.home.homeDirectory;
in
lib.mkIf needsSharedServerMaintenance {
  home.activation.mcpObsoleteNpmGlobal = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export PATH=${
      lib.makeBinPath [
        pkgs.nodejs
        pkgs.coreutils
      ]
    }:$PATH
    ${mkNpmGlobalObsoleteRemovalActivation homeDir}
  '';
}
