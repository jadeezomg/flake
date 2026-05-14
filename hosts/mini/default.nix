{
  config,
  lib,
  pkgs,
  ...
}: let
  # Bootstrap toggle — breaks the sops/host-key chicken-and-egg.
  #
  # On a fresh install the SSH host key doesn't exist yet, so sops-nix can't
  # decrypt `users/jadee/password` during the first activation. Set this to
  # `true` for the very first `nixos-install`; jadee gets `initialPassword`
  # ("changeme") and the sops secret is skipped. After §5.4 in
  # docs/hosts/mini-install.md (host added to .sops.yaml, secrets rekeyed),
  # flip to `false`, commit, `just switch` — jadee's password becomes the
  # sops-managed one.
  bootstrap = true;
in {
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    ../../modules/shared
    ../../modules/nixos
    ./profiles.nix
    ./hermes.nix
    # Nightly cachix pipeline — disabled until the host is up and the cache is
    # bootstrapped. Re-enable after following docs/hosts/mini-install.md §6.
    # ./flake-cache-warm.nix
  ];

  # NOPASSWD wheel — quality-of-life over SSH on a key-only headless host.
  # Desktop/framework keep password-required sudo (gated by hostKey == "mini"
  # is unnecessary because this file only loads for the mini host).
  security.sudo.wheelNeedsPassword = false;

  # Aggressive GC for the cache-warming host: 256 GB NVMe + nightly multi-closure
  # builds means the local store fills fast. Cachix holds the canonical artefacts.
  maintenance.garbageCollection = {
    schedule = "daily";
    deleteOlderThan = "3d";
  };

  # Static IP via NetworkManager, matching router-side reservation.
  # TODO: fill in the real address1 / dns / interface name during install.
  networking.networkmanager.ensureProfiles.profiles."mini-lan" = {
    connection = {
      id = "mini-lan";
      type = "ethernet";
      interface-name = "enp2s0f0"; # adjust on first boot if naming differs
      autoconnect = true;
    };
    ipv4 = {
      method = "manual";
      # Format: <address>/<prefix>,<gateway>
      address1 = "192.168.1.10/24,192.168.1.1";
      dns = "1.1.1.1;9.9.9.9";
    };
    ipv6.method = "auto";
  };

  # Compressed RAM swap — 8 GB is tight for nix builds; zram cushions OOM
  # without burning NVMe writes. Add real swap only if we hit recurring OOMs.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  # AMT / vPro — non-root /dev/mei access for amtterm / openwsman.
  users.groups.amt = {};
  services.udev.extraRules = ''
    KERNEL=="mei*", GROUP="amt", MODE="0660"
  '';

  # Intel CSME firmware updates over LVFS — critical for AMT CVE patching.
  services.fwupd.enable = true;

  # AMT controller tools (also useful here for SOL-from-localhost debugging).
  environment.systemPackages = with pkgs; [
    amtterm
    openwsman
  ];

  # SSH — key-only, jadee-only.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = ["jadee"];
    };
  };

  # --- sops-nix (system-level) ---
  # Mini's age key is derived from its SSH host key (ed25519). Add the host's
  # public age recipient to `.sops.yaml` and re-encrypt secrets/secrets.yaml
  # before running `nixos-rebuild switch` for the first time on the box.
  # See docs/hosts/mini-install.md §5.4 for the bootstrap procedure.
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
  };

  # Declarative password — sourced from sops, replaces manual `passwd`.
  # The secret must exist in secrets/secrets.yaml under `users/jadee/password`
  # encrypted to mini's host age key (see docs/hosts/mini-install.md §5.4).
  # Gated on `bootstrap` so the very first install doesn't try to decrypt
  # before mini's age key exists.
  sops.secrets."users/jadee/password" = lib.mkIf (!bootstrap) {
    neededForUsers = true;
  };
  users.users.jadee = lib.mkMerge [
    {extraGroups = ["amt"];}
    (lib.mkIf bootstrap {
      initialPassword = "changeme";
    })
    (lib.mkIf (!bootstrap) {
      hashedPasswordFile = config.sops.secrets."users/jadee/password".path;
    })
  ];

  # System state version — host specific, do not change.
  system.stateVersion = "26.05";
}
