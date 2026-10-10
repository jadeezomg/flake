# Core dev tooling — the system packages plus the HM half (mise).
{ dotfilesLib, ... }@args:
dotfilesLib.mkProfile {
  path = [ "devenv" ];
  # mise — polyglot tool/runtime version manager and task runner. Darwin only
  # for now. home-manager writes the shell activation snippets for it.
  hm = [ ({ pkgs, ... }: { programs.mise.enable = pkgs.stdenv.hostPlatform.isDarwin; }) ];

  packages =
    pkgs: with pkgs; [
      # --- Build essentials (migrated from modules/shared/utils/core.nix) ---
      gnumake
      gcc
      gdb
      pkg-config

      # --- Version control ---
      jujutsu
      jjui
      gh
      lazygit
      gh-dash

      # --- Task runners ---
      just
      act
      watchexec

      # --- Code metrics & analysis ---
      tokei
      diffnav

      # --- Session recording ---
      asciinema
    ];
} args
