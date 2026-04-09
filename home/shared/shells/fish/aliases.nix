{hostKey ? "framework", ...}: let
  sharedAliases = import ../shared/aliases.nix;
  sharedPaths = import ../shared/paths.nix;
  sharedConfig = import ../shared/config.nix;
  finalHostKey = hostKey;
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

    # Home Manager shortcuts
    function hm
      nix run ${sharedConfig.nixConfig.homeManagerFlake} -- --flake "${sharedPaths.commonPaths.flake}#${finalHostKey}"
    end
    function hms
      nix run ${sharedConfig.nixConfig.homeManagerFlake} -- switch --flake "${sharedPaths.commonPaths.flake}#${finalHostKey}"
    end
    function hmn
      nix run ${sharedConfig.nixConfig.homeManagerFlake} -- news --flake "${sharedPaths.commonPaths.flake}#${finalHostKey}"
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

    # pay-respects integration
    function f -d "Suggest fixes to the previous command"
      eval $(_PR_LAST_COMMAND="$(history | head -n 1)" _PR_ALIAS="$(alias)" _PR_SHELL="fish" "pay-respects")
    end

    if status is-interactive
      function fish_command_not_found --on-event fish_command_not_found
        eval $(_PR_LAST_COMMAND="$argv" _PR_ALIAS="$(alias)" _PR_SHELL="fish" _PR_MODE="cnf" "pay-respects")
      end
    end
  '';
}
