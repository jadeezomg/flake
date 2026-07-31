{
  dotfilesLib,
  inputs,
  lib,
  pkgs,
  host,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    inputs.disko.nixosModules.disko
    ./disko.nix
    ../../modules/shared
    ../../modules/nixos
    ../../modules/profiles
    ./profiles.nix
    inputs.hermes-agent.nixosModules.default
    ./services/caddy.nix
    ./services/hermes.nix
    ./services/hermes-dashboard.nix
    ./services/matrix.nix
    ./services/cinny.nix
    # Nightly cachix pipeline — disabled until the host is up (mini-install.md §6).
    # ./flake-cache-warm.nix
  ]
  ++ lib.optionals (host.miniLlmHosting or false) [
    # Self-contained chat stack: shared base + open-webui + the backend selected
    # (see hosts/mini/services/llm/default.nix).
    ./services/llm
  ]
  ++ lib.optionals (host.miniMonitoring or false) [ ./services/beszel.nix ]
  ++ lib.optionals (host.miniMediaHosting or false) [
    inputs.nixflix.nixosModules.default
    ./services/media
  ];
  # NOPASSWD wheel — quality-of-life over SSH on a key-only headless host.
  # Desktop/framework keep password-required sudo (gated by hostKey == "mini"
  # is unnecessary because this file only loads for the mini host).
  security.sudo.wheelNeedsPassword = false;

  maintenance.garbageCollection = {
    schedule = "daily";
    deleteOlderThan = "3d";
  };

  networking.networkmanager.ensureProfiles.profiles."mini-lan" = {
    connection = {
      id = "mini-lan";
      type = "ethernet";
      interface-name = "enp2s0f0np0";
      autoconnect = true;
    };
    ipv4 = {
      method = "manual";
      # Format: <address>/<prefix>,<gateway>
      address1 = "192.168.178.100/24,192.168.178.1";
      dns = "1.1.1.1;9.9.9.9";
    };
    ipv6.method = "auto";
  };

  # Intel GPU (graphics.enable via dotfiles.hardware.gpu = "intel"):
  # Vulkan llama.cpp stack lives under ./services/llm/.

  # AMT / vPro — non-root /dev/mei access for amtterm / openwsman.
  users.groups.amt = { };
  services.udev.extraRules = ''
    KERNEL=="mei*", GROUP="amt", MODE="0660"
  '';

  # Kitty (and other modern terminals) set TERM=xterm-kitty; SSH forwards it.
  # Without matching terminfo on the server, tools complain ('unknown terminal type')
  # or behave oddly. Pulls small terminfo-only outputs (kitty, ghostty, foot, …).
  environment.enableAllTerminfo = true;

  # Intel CSME firmware updates over LVFS — critical for AMT CVE patching.
  services.fwupd.enable = true;
  # `fwupd-refresh.service` runs during switch; it often races a restarting
  # `fwupd.service` or LVFS (client/daemon mismatch, nixpkgs#288598) and exits 1,
  # which makes switch-to-configuration return 4. Treat those as non-fatal;
  # run `fwupdmgr refresh` / `fwupdmgr update` when you care about metadata.
  #
  # Guarded, not exact: nixpkgs#288598 is still open and "the race stopped
  # happening" is not observable at eval time, so this nags on a future fwupd
  # rather than retiring itself. Still in place as of fwupd 2.1.6.
  systemd.services.fwupd-refresh.serviceConfig.SuccessExitStatus =
    (dotfilesLib.expiry { inherit lib; } "hosts/mini/default.nix").recheckWhen
      {
        stale = lib.versionAtLeast pkgs.fwupd.version "2.3";
        reason = "fwupd reached 2.3 (workaround still in place at 2.1.6); recheck https://github.com/NixOS/nixpkgs/issues/288598 and drop this if switch no longer fails.";
      }
      (
        lib.mkForce [
          1
          2
        ]
      );

  # AMT controller tools (also useful here for SOL-from-localhost debugging).
  environment.systemPackages = with pkgs; [
    amtterm
    openwsman
  ];

  # Password handling is the generic path (modules/nixos/user.nix →
  # `users/jadee/password_mini`); only host-specific groups remain here.
  users.users.jadee.extraGroups = [
    "amt"
    "render"
  ];

  # System state version — host specific, do not change.
  system.stateVersion = "26.05";
}
