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

    # Flake build scripts shortcuts
    function flake
      nu "${sharedPaths.commonPaths.flake}/${sharedConfig.nixConfig.flakeBuildScript}"
    end
  '';
}
