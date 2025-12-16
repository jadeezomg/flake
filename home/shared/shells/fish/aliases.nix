{hostKey ? "framework", ...}: let
  sharedAliases = import ../shared/aliases.nix;
in {
  # Import common aliases
  programs.fish.shellAliases = sharedAliases.commonAliases;

  # Fish-specific function implementations
  programs.fish.interactiveShellInit = ''
    # Quick directory navigation shortcuts
    function zz
      cd $HOME
    end
    function zc
      cd $HOME/.config
    end
    function zd
      cd $HOME/Downloads
    end
    function zp
      cd $HOME/.dotfiles
    end
    function zf
      cd $HOME/.dotfiles/flake
    end

    # Home Manager shortcuts
    function hm
      nix run home-manager/master -- --flake "$HOME/.dotfiles/flake#${hostKey}"
    end
    function hms
      nix run home-manager/master -- switch --flake "$HOME/.dotfiles/flake#${hostKey}"
    end
    function hmn
      nix run home-manager/master -- news --flake "$HOME/.dotfiles/flake#${hostKey}"
    end

    # Flake build scripts shortcuts
    function flake
      nu "$HOME/.dotfiles/flake/build/flake.nu"
    end
  '';
}
