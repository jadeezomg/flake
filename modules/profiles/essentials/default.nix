{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.essentials;
in {
  config = lib.mkIf cfg.enable {
    # HM widgets: host-status service/timer, fastfetch config, CLI utils
    # (television cable, navi cheats, yazi, …).
    home-manager.sharedModules = [
      ./host-status.nix
      ./fastfetch.nix
      ./utils
    ];

    environment.systemPackages = with pkgs; [
      # --- Text / docs polish ---
      ripgrep-all # ripgrep for archives, pdfs, etc.
      exiftool
      qpdf
      pdftk

      # --- Networking polish ---
      ipfetch
      resterm

      # --- Nix workstation tooling ---
      cachix
      nixos-icons
      comma
      nurl
      nix-init
      nix-direnv
    ];
  };
}
