{
  inputs,
  lib,
  pkgs,
  host,
  ...
}: {
  imports =
    [
      ./hardware-configuration.nix
      inputs.disko.nixosModules.disko
      ./disko.nix
      ../../modules/shared
      ../../modules/nixos
      ../../modules/profiles
      ./profiles.nix
      inputs.hermes-agent.nixosModules.default
      ./services/hermes.nix
      # Nightly cachix pipeline — disabled until the host is up (mini-install.md §6).
      # ./flake-cache-warm.nix
    ]
    ++ lib.optionals (host.miniLlmHosting or false) (
      [
        # Shared GPU stack + HF token; the contract lives in host.nix. Always present.
        ./services/llm-base.nix
        ./services/open-webui.nix
      ]
      # Exactly one chat backend (shared GPU). Both honour the same contract, so
      # open-webui/honcho are unaffected by which one is selected.
      ++ lib.optionals ((host.miniLlmBackend or "vllm") == "vllm") [
        # vllm-xpu-nix: `nixosModules.default` = overlay + `services.vllm-xpu` (see upstream
        # https://github.com/jasonboukheir/vllm-xpu-nix/blob/main/docs/nixos-overlay.md ).
        inputs.vllm-xpu-nix.nixosModules.default
        ./services/vllm-xpu.nix
      ]
      ++ lib.optionals ((host.miniLlmBackend or "vllm") == "llamacpp") [
        ./services/llama-cpp.nix
      ]
    )
    ++ lib.optionals (
      (host.miniLlmHosting or false)
      && (host.miniMemoryHosting or false)
    ) [./services/honcho.nix]
    ++ lib.optionals (host.miniMonitoring or false) [./services/beszel.nix];
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
      interface-name = "enp6s0f0np0";
      autoconnect = true;
    };
    ipv4 = {
      method = "manual";
      # Format: <address>/<prefix>,<gateway>
      address1 = "192.168.178.100/24,192.168.178.255";
      dns = "1.1.1.1;9.9.9.9";
    };
    ipv6.method = "auto";
  };

  # Intel GPU (graphics.enable via dotfiles.hardware.gpu = "intel"):
  # vLLM-XPU + Vulkan llama.cpp stacks live in ./vllm-xpu.nix and ./llama-cpp.nix.

  # AMT / vPro — non-root /dev/mei access for amtterm / openwsman.
  users.groups.amt = {};
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
  systemd.services.fwupd-refresh.serviceConfig.SuccessExitStatus = lib.mkForce [1 2];

  # AMT controller tools (also useful here for SOL-from-localhost debugging).
  environment.systemPackages = with pkgs; [
    amtterm
    openwsman
  ];

  # Password handling is the generic path (modules/nixos/user.nix →
  # `users/jadee/password_mini`); only host-specific groups remain here.
  users.users.jadee.extraGroups = ["amt" "render"];

  # System state version — host specific, do not change.
  system.stateVersion = "26.05";
}
