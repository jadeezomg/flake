{hostKey ? "framework", ...}: let
  sharedAliases = import ../shared/aliases.nix;
in {
  # Import common aliases
  programs.bash.shellAliases = sharedAliases.commonAliases;

  # Bash-specific function implementations
  programs.bash.initExtra = ''
    # Quick directory navigation shortcuts
    zz() { cd "$HOME"; }
    zc() { cd "$HOME/.config"; }
    zd() { cd "$HOME/Downloads"; }
    zp() { cd "$HOME/.dotfiles"; }
    zf() { cd "$HOME/.dotfiles/flake"; }

    # Home Manager shortcuts
    hm() { nix run home-manager/master -- --flake "$HOME/.dotfiles/flake#${hostKey}"; }
    hms() { nix run home-manager/master -- switch --flake "$HOME/.dotfiles/flake#${hostKey}"; }
    hmn() { nix run home-manager/master -- news --flake "$HOME/.dotfiles/flake#${hostKey}"; }

    # Flake build scripts shortcuts
    flake() { nu "$HOME/.dotfiles/flake/build/flake.nu"; }
  '';
}
