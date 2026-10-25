let
  inherit (import ../lib.nix) sharedNixOSHost sharedNixOSUser;
in
sharedNixOSHost
// {
  hostname = "framework";
  nixpkgsConfig = {
    rocmSupport = true;
  };
  user = sharedNixOSUser;
  dmsSettingsFile = "settings-framework.json";
  niriOutputsFile = "outputs-framework.kdl";

  # Public half of ~/.ssh/agent_push_ed25519, made by the first switch
  # (modules/profiles/devenv/agents/session-push.nix). mini lets it write into
  # /srv/agent-sessions/framework only.
  agentPushKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB/p3MCOz02bYT6LZKyoke0Ar+tQO5voGTow466UhFaW agent-push@framework";
}
