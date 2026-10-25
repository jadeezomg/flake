let
  inherit (import ../lib.nix) sharedNixOSHost sharedNixOSUser;
in
sharedNixOSHost
// {
  hostname = "desktop";
  user = sharedNixOSUser;
  buildCores = 24;
  dmsSettingsFile = "settings-desktop.json";
  niriOutputsFile = "outputs-desktop.kdl";
  gdmMonitorsFile = "monitors-desktop.xml";

  # Public half of ~/.ssh/agent_push_ed25519, made by the first switch
  # (modules/profiles/devenv/agents/session-push.nix). mini lets it write into
  # /srv/agent-sessions/desktop only.
  agentPushKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICOMMFFHN8vxq/kEPy5lGoKBqjxWrYFCV0wIF1P217Et agent-push@desktop";
}
