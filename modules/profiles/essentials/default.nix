{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.profiles.essentials;
in
{
  config = lib.mkIf cfg.enable {
    # HM widgets: host-status service/timer, fastfetch config, CLI utils
    # (television cable, navi cheats, yazi), prompt/shell theming, and the
    # workstation env exports (FLAKE, PATH, flake helpers).
    home-manager.sharedModules = [
      ./host-status.nix
      ./fastfetch.nix
      ./utils
      ./shell-theme
      ./shell-system-env.nix
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

      # --- Security / crypto ---
      openssl

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
