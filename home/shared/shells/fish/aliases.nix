{...}: let
  sharedAliases = import ../shared/aliases.nix;
  sharedPaths = import ../shared/paths.nix;
in {
  # Import common aliases
  programs.fish.shellAliases = sharedAliases.commonAliases;

  # Fish-specific function implementations
  programs.fish.interactiveShellInit = ''
    # Quick directory navigation shortcuts
    function zz
      cd ${sharedPaths.commonPaths.home}
    end
    function zc
      cd ${sharedPaths.commonPaths.config}
    end
    function zd
      cd ${sharedPaths.commonPaths.downloads}
    end
    function zp
      cd ${sharedPaths.commonPaths.dotfiles}
    end
    function zf
      cd ${sharedPaths.commonPaths.flake}
    end

    function flake
      set -l j "${sharedPaths.commonPaths.flake}/Justfile"
      if test (count $argv) -gt 1
        set -l sub $argv[1]
        if contains $sub build switch generation gc fmt backups
          set -e argv[1]
          just --justfile $j _$sub $argv
          return
        else if test "$sub" = init
          set -e argv[1]
          just --justfile $j _init $argv
          return
        else if test "$sub" = read-defaults
          set -e argv[1]
          just --justfile $j _read-defaults $argv
          return
        end
      end
      just --justfile $j $argv
    end
    function nuflake
      nu "${sharedPaths.commonPaths.flake}/build/flake.nu" $argv
    end
  '';
}
