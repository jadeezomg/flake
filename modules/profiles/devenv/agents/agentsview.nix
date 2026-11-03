# caya's own agentsview server. caya keeps its work sessions to itself (D1 in
# docs/agents/session-management-plan.md), so it indexes its local agent
# folders here instead of pushing them to the archive on mini. The agentsview
# MCP entry in ./apm.nix reads this server on caya and the archive on mini
# everywhere else (agentsviewServer in lib/nono-profiles.nix).
#
# It runs as a launchd agent, outside the nono sandbox, because it must read
# the session folders of every agent and write its own data folder.
{
  config,
  dotfilesLib,
  isDarwin,
  lib,
  pkgs,
  ...
}:
let
  inherit (dotfilesLib.nonoProfiles { inherit pkgs; }) agentsviewPort;
in
lib.mkIf isDarwin {
  launchd.agents.agentsview = {
    enable = true;
    config = {
      ProgramArguments = [
        "${pkgs.llm-agents.agentsview}/bin/agentsview"
        "serve"
        "--host"
        "127.0.0.1"
        "--port"
        (toString agentsviewPort)
        "--no-browser"
        "--no-update-check"
      ];
      EnvironmentVariables = {
        AGENTSVIEW_TELEMETRY_ENABLED = "0";
        AGENTSVIEW_DISABLE_UPDATE_CHECK = "1";
      };
      KeepAlive = true;
      RunAtLoad = true;
      ProcessType = "Background";
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/agentsview.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/agentsview.log";
    };
  };
}
