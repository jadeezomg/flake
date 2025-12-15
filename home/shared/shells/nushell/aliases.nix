{hostKey ? "framework", ...}: {
  programs.nushell.shellAliases = {
    # Replace default tools with better alternatives
    cat = "bat";
    find = "fd";
    grep = "rg";

    # eza
    l2 = "eza --icons -l -T -L=2";
    l3 = "eza --icons -l -T -L=3";
    llt = "eza -T";
    lat = "eza -Ta";
    tree = "eza -Ta";
    lat1 = "eza -Ta -L=1";
    lat2 = "eza -Ta -L=2";
    lat3 = "eza -Ta -L=3";
    lat4 = "eza -Ta -L=4";
    lat5 = "eza -Ta -L=5";

    # Navigation shortcuts
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
    # Aliases that need nushell syntax
    # alias cd = z
    # alias lf = yy

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
  '';
}
