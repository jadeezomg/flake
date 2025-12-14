{
  hostKey ? "framework",
  ...
}:

{
  programs.nushell.shellAliases = {
    # Replace default tools with better alternatives
    cat = "bat";
    find = "fd";
    grep = "rg";

    # Navigation shortcuts
    cd = "z";
    ".." = "z ..";
    "..." = "z ../..";
    "...." = "z ../../..";
    "....." = "z ../../../..";

    # Editor shortcuts
    zed = "zeditor";
    code = "cursor";

    # General shortcuts
    cl = "clear";
    h = "history";

    # Git shortcuts
    gst = "git status";
    gad = "git add .";
    gcm = "git commit -m";
    gpu = "git push -u origin main";

    search = "rg --smart-case";
    searchf = "fd --type f";
    searchd = "fd --type d";
  };

  # Nushell-specific aliases that need nushell syntax
  programs.nushell.extraConfig = ''
    # Quick directory navigation shortcuts
    def --env zz [] { 
      cd ''$env.HOME
    }
    def --env zc [] { 
      cd $"(''$env.HOME)/.config"
    }
    def --env zd [] { 
      cd $"(''$env.HOME)/Downloads"
    }
    def --env zp [] { 
      cd $"(''$env.HOME)/.dotfiles"
    }
    def --env zf [] { 
      cd $"(''$env.HOME)/.dotfiles/flake"
    }

    # Search aliases
    alias search = rg --smart-case
    alias searchf = fd --type f
    alias searchd = fd --type d

    # Home Manager shortcuts (using nushell string interpolation)
    # alias hm = home-manager --flake $"($env.FLAKE)#${hostKey}"
    # alias hms = home-manager switch --flake $"($env.FLAKE)#${hostKey}"
    # alias hmn = home-manager news --flake $"($env.FLAKE)#${hostKey}"
    alias hm = nix run home-manager/master -- --flake $"($env.FLAKE)#${hostKey}"
    alias hms = nix run home-manager/master -- switch --flake $"($env.FLAKE)#${hostKey}"
    alias hmn = nix run home-manager/master -- news --flake $"($env.FLAKE)#${hostKey}"


    # Flake build scripts shortcuts
    alias flake = nu $"($env.FLAKE)/build/flake.nu"
    alias flake-init = nu $"($env.FLAKE)/build/init.nu"
    alias flake-build = nu $"($env.FLAKE)/build/build.nu"
    alias flake-switch = nu $"($env.FLAKE)/build/switch.nu"
    alias flake-update = nu $"($env.FLAKE)/build/update.nu"
    alias flake-gc = nu $"($env.FLAKE)/build/gc.nu"
    alias flake-health = nu $"($env.FLAKE)/build/health.nu"
    alias flake-rollback = nu $"($env.FLAKE)/build/rollback.nu"
    alias flake-generation = nu $"($env.FLAKE)/build/generation.nu"
    alias flake-caches = nu $"($env.FLAKE)/build/update-caches.nu"
    alias flake-info = nu $"($env.FLAKE)/build/flake-info.nu"
    alias flake-check-backups = nu $"($env.FLAKE)/build/check-backups.nu"
    alias flake-clean-backups = nu $"($env.FLAKE)/build/clean-backups.nu"
    alias flake-fmt = nu $"($env.FLAKE)/build/fmt.nu"
    alias flake-reload-services = nu $"($env.FLAKE)/build/reload-services.nu"
    alias flake-untracked = nu $"($env.FLAKE)/build/git-update.nu"
  '';
}
