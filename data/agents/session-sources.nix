# Where each terminal agent keeps its sessions, relative to $HOME.
#
# The attribute name is the folder in the archive on mini:
# /srv/agent-sessions/<host>/<name>/. The push on each host
# (modules/profiles/devenv/agents/session-push.nix) and agentsview on mini
# (hosts/mini/services/agent-sessions.nix) read this list.
#
#   path     the folder to send, in the agent's own layout
#   parser   the agentsview parser name for that folder
#   sqlite   send only a `.backup` snapshot of this database file
#   exclude  rsync exclude patterns
{
  claude = {
    path = ".claude/projects";
    parser = "claude";
  };
  pi = {
    path = ".pi/agent/sessions";
    parser = "pi";
  };
  omp = {
    path = ".omp/agent/sessions";
    parser = "omp";
    # Command output of each session, not transcript (177 MB on desktop).
    exclude = [ "*.log" ];
  };
  codex = {
    path = ".codex/sessions";
    parser = "codex";
  };
  opencode = {
    path = ".local/share/opencode";
    parser = "opencode";
    sqlite = "opencode.db";
  };
  dsh = {
    path = ".dsh/sessions";
    parser = "deepseek-harness";
  };
}
