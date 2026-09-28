# Core dev tooling — the system packages plus the HM half (mise).
{ dotfilesLib, ... }@args:
dotfilesLib.mkProfile {
  path = [ "devenv" ];
  # mise — polyglot tool/runtime version manager and task runner. mise is
  # inside the nix closure on both platforms, so home-manager generates the
  # shell activation snippets at build time. nushell gets a store path it can
  # `use`, which is why the writable-cache dance the Homebrew mise needed on
  # Darwin is gone.
  hm = [ { programs.mise.enable = true; } ];

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
