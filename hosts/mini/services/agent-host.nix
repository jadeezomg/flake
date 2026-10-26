# mini as agent host: mode `mini` (A) in docs/agents/session-management-plan.md.
#
# Agents run on mini inside herdr or tuios sessions of jadee. Both tools start
# their server from the first client that attaches, so the server, the agents
# and their builds and tests run in jadee's user slice, not in a unit of their
# own. This file caps that slice, so that agent work cannot take the memory that
# llama.cpp, Immich and the media stack need. Nix builds are not affected: they
# run in nix-daemon, outside the user slice.
#
# MemoryHigh starts reclaim and throttling. MemoryMax is the hard stop: the
# kernel kills a process in the slice when the slice reaches it.
#
# jadee's UID on mini is 1000. The flake sets no uid (data/users/users.nix), so
# NixOS assigned it. Checked with `id -u` on 2026-10-26.
_: {
  systemd.slices."user-1000" = {
    overrideStrategy = "asDropin";
    sliceConfig = {
      MemoryHigh = "8G";
      MemoryMax = "10G";
    };
  };
}
