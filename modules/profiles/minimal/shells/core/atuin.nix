# Atuin shell history. Every host syncs to mini's own server
# (hosts/mini/services/atuin.nix), never to the public api.atuin.sh.
#
# The address resolves over the tailnet, and on the LAN when local DNS points at
# mini. Off both networks, sync fails quietly and history stays local until the
# next connection.
#
# Sync needs a one-time `atuin login` per host — see the onboarding steps in
# hosts/mini/services/atuin.nix.
_: {
  programs.atuin = {
    enable = true;
    settings = {
      sync_address = "https://atuin.jadee.fyi";
      auto_sync = true;
      sync_frequency = "5m";
    };
  };
}
