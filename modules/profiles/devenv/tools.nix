# Core dev tooling — the system packages. mise is Darwin only, from Homebrew
# (./mise-darwin.nix says why).
{
  dotfilesLib,
  isDarwin ? false,
  lib,
  ...
}@args:
dotfilesLib.mkProfile {
  path = [ "devenv" ];
  # The `homebrew.*` namespace only exists on darwin, hence the import gate.
  imports = lib.optionals isDarwin [ ./mise-darwin.nix ];

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
