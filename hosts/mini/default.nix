{
  config,
  lib,
  pkgs,
  ...
}: let
  # Bootstrap toggle — breaks the sops host-age-key chicken-and-egg.
  #
  # On a fresh install `/var/lib/private/sops/age/keys.txt` does not exist yet,
  # so sops-nix can't decrypt `users/jadee/password_mini` during activation.
  # Set `true` for the very first `nixos-install`; jadee gets `initialPassword`
  # ("changeme") and the sops secret is skipped. After §5.4 in
  # docs/hosts/mini-install.md (host key bootstrapped, `.sops.yaml` updated,
  # secrets rekeyed), flip to `false`, commit, `just switch`.
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

  # Cache-warming host: nightly multi-closure builds still churn through /nix.
  # Keep GC conservative on the 256 GB system SSD; Cachix holds canonical artefacts.
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

  # Declarative password — sourced from sops, replaces manual `passwd`.
  # Requires `users/jadee/password_mini` in secrets/secrets.yaml and mini's host
  # age pubkey in `.sops.yaml` (see docs/hosts/mini-install.md §5.4).
  # Gated on `bootstrap` until `/var/lib/private/sops/age/keys.txt` exists.
  sops.secrets."users/jadee/password_mini" = lib.mkIf (!bootstrap) {
    neededForUsers = true;
  };
  users.users.jadee = lib.mkMerge [
    {extraGroups = ["amt"];}
    (lib.mkIf bootstrap {
      initialPassword = "changeme";
    })
    (lib.mkIf (!bootstrap) {
      hashedPasswordFile = config.sops.secrets."users/jadee/password_mini".path;
    })
  ];

  # System state version — host specific, do not change.
  system.stateVersion = "26.05";
}
