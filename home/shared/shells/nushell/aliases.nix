{
  hostKey ? "framework",
  pkgs,
  ...
}: let
  sharedAliases = import ../shared/aliases.nix;
  sharedPaths = import ../shared/paths.nix;
  sharedConfig = import ../shared/config.nix;
  finalHostKey = hostKey;
  # Extract relative path parts from shared paths (remove $HOME/ prefix)
  configPath = builtins.replaceStrings ["$HOME/"] [""] sharedPaths.commonPaths.config;
  downloadsPath = builtins.replaceStrings ["$HOME/"] [""] sharedPaths.commonPaths.downloads;
  dotfilesPath = builtins.replaceStrings ["$HOME/"] [""] sharedPaths.commonPaths.dotfiles;

  # Fetch git.nu from fj0r's repository
  gitNu = pkgs.fetchFromGitHub {
    owner = "fj0r";
    repo = "git.nu";
    rev = "main";
    sha256 = "sha256-7twPTScOXW8RqgDAKx0mzwYVeQrmj3cP9dFO9PBRclA="; # Updated hash
  };

  # Fetch bash-env.nu module from tesujimath's repository
  # https://github.com/tesujimath/bash-env-nushell
  bashEnvNu = pkgs.fetchFromGitHub {
    owner = "tesujimath";
    repo = "bash-env-nushell";
    rev = "main";
    sha256 = "sha256-iNskiGPB4PANxlnCMzAxqkkwfsukWR5AFW5o86g/oP8=";
  };
in {
  # Import common aliases
  programs.nushell.shellAliases = sharedAliases.commonAliases;

  # Add bash-env-json as a dependency (required by bash-env.nu)
  home.packages = [pkgs.bash-env-json];

  # Nushell-specific function implementations
  programs.nushell.extraConfig = ''
    # Source git.nu workflow commands from fj0r/git.nu
    # https://github.com/fj0r/git.nu
    # Import the main module and shortcut aliases (gs, gl, gb, gp, ga, gc, gd, gm, gr, etc.)
    use ${gitNu}/git/mod.nu *
    use ${gitNu}/git/shortcut.nu *

    # Source bash-env.nu module from tesujimath/bash-env-nushell
    # https://github.com/tesujimath/bash-env-nushell
    # Allows loading bash environment files into Nushell
    # Usage: bash-env ./path/to/file.env | load-env
    #        ssh-agent | bash-env | load-env
    use ${bashEnvNu}/bash-env.nu *

    # Quick directory navigation shortcuts
    # Using shared paths converted to Nushell syntax ($HOME -> $env.HOME)
    def --env zz [] { cd ''$env.HOME }
    def --env zc [] { cd $"(''$env.HOME)/${configPath}" }
    def --env zd [] { cd $"(''$env.HOME)/${downloadsPath}" }
    def --env zp [] { cd $"(''$env.HOME)/${dotfilesPath}" }
    def --env zf [] { cd ''$env.FLAKE }

    # Home Manager shortcuts
    alias hm = nix run ${sharedConfig.nixConfig.homeManagerFlake} -- --flake $"(''$env.FLAKE)#${finalHostKey}"
    alias hms = nix run ${sharedConfig.nixConfig.homeManagerFlake} -- switch --flake $"(''$env.FLAKE)#${finalHostKey}"
    alias hmn = nix run ${sharedConfig.nixConfig.homeManagerFlake} -- news --flake $"(''$env.FLAKE)#${finalHostKey}"

    # Flake build scripts shortcuts
    alias flake = nu $"(''$env.FLAKE)/${sharedConfig.nixConfig.flakeBuildScript}"

    def --env f [] {
      let dir = (with-env { _PR_LAST_COMMAND: (history | last).command, _PR_ALIAS: (help aliases | select name expansion | each ({ |row| $row.name + "=" + $row.expansion }) | str join (char nl)), _PR_SHELL: nu } { /home/jadee/.nix-profile/bin/pay-respects })
      cd $dir
    }
  '';
}
