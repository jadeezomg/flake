{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.minimal;
in {
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # --- Daily-driver CLIs ---
      ripgrep
      fd
      bat
      eza
      fzf
      zoxide
      jq
      yq
      sd
      dust
      broot
      difftastic
      dua
      btop
      hyperfine
      gping
      xh
      httpie
      delta
      poppler-utils
      yazi

      # --- Filesystem core ---
      file
      gawk
      libarchive
      lsof
      p7zip
      unzip
      uutils-coreutils-noprefix # Rust coreutils rewrite (relocated from nixos/utils)
      zip

      # --- Networking core ---
      curl
      dig
      wget

      # --- Nix bootstrap ---
      nh
      nix-index
    ];
  };
}
