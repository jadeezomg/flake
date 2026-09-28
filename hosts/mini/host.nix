let
  inherit (import ../lib.nix) sharedNixOSHost sharedNixOSUser;
  lanAddress = "192.168.178.100";
in
sharedNixOSHost
// {
  hostname = "mini";
  user = sharedNixOSUser;

  # Gates the local LLM stack (`./services/llm`): it turns on the shared llama.cpp
  # router `dotfiles.profiles.llm.serve` with mini's models (`local-chat` +
  # `local-embed` on :8000) and adds open-webui. All serving knobs live there.
  miniLlmHosting = true;

  # Beszel hub + agent (./services/beszel.nix): server/service/container monitoring.
  miniMonitoring = true;

  # Atuin sync server (./services/atuin.nix): shell history for every host, on
  # the postgres this box already runs. Clients point at atuin.jadee.fyi.
  miniAtuinSync = true;

  # Nixflix media stack (./services/media/): automation and playback on mini,
  # with library and download payloads mounted from Unraid.
  miniMediaHosting = true;

  # Immich photo/video library (./services/immich.nix) + its off-host backup to
  # Unraid (./services/immich-backup.nix). Migrated off the Unraid container;
  # brings this host's first postgresql + redis. Unlike the media stack, the
  # payload lives on mini's local NVMe and Unraid is the backup target —
  # see docs/adr/0007-immich-library-on-mini.md.
  miniImmich = true;

  # Static LAN address on enp2s0f0np0 (see default.nix mini-lan NM profile).
  miniLanAddress = lanAddress;

  # Reach mini by address, not by name: it is headless and `just mini <cmd>`
  # must work before any name resolution does. Feeds the `mini` ssh alias via
  # data/network/ssh-destinations.nix.
  sshAddress = lanAddress;

  # Also serve Caddy vhosts on the LAN IP (same *.jadee.fyi names; needs local DNS).
  miniCaddyLanEnable = true;

  # No guest accounts on a headless server.
  extraUsers = [ ];

  # 24 GiB RAM: keep local rebuild parallelism modest on a headless server.
  buildCores = 2;

  # Disabled until sbctl keys exist on the installed host. Flip to true in git
  # after `sudo sbctl create-keys`, then switch to let lanzaboote sign /boot.
  secureBoot = false;

  stateVersion = "26.05";
  # Note: dmsSettingsFile / niriOutputsFile intentionally omitted.
  # The desktop profile (disabled here) carries the desktop HM tree.
}
