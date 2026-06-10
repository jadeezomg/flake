{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.essentials;
in {
  config = lib.mkIf cfg.enable {
    # HM widgets: host-status service/timer + fastfetch config.
    home-manager.sharedModules = [
      ./host-status.nix
      ./fastfetch.nix
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
