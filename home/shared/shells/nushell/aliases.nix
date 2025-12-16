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
    sha256 = "sha256-bEQ5NGpFHox8fzFjoa6ETTmEzlOC/Ka6nSdVvOaDDb0=";
  };
in {
  # Import common aliases
  programs.nushell.shellAliases = sharedAliases.commonAliases;

  # Nushell-specific function implementations
  programs.nushell.extraConfig = ''
    # Source git.nu workflow commands from fj0r/git.nu
    # https://github.com/fj0r/git.nu
    # Import the main module and shortcut aliases (gs, gl, gb, gp, ga, gc, gd, gm, gr, etc.)
    use ${gitNu}/git/mod.nu *
    use ${gitNu}/git/shortcut.nu *

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
  '';
}
