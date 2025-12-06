{ ... }:

{
  programs.nushell.shellAliases = {
    # Replace default tools with better alternatives
    cat = "bat";
    find = "fd";
    grep = "rg";
    
    # Navigation shortcuts
    cd = "z";
    ".." = "cd ..";
    "..." = "cd ../..";
    "...." = "cd ../../..";
    "....." = "cd ../../../..";
    
    # Editor shortcuts
    zed = "zeditor";
    
    # General shortcuts
    cl = "clear";
    h = "history";
    
    # Git shortcuts
    gst = "git status";
    gad = "git add .";
    gcm = "git commit -m";
    gpu = "git push -u origin main";
  };

  # Nushell-specific aliases that need nushell syntax
  programs.nushell.extraConfig = ''
    # Quick directory navigation using zoxide
    # Use 'z' for smart navigation, or these shortcuts for common directories
    alias zz = z $env.HOME
    alias zc = z $env.XDG_CONFIG_HOME
    alias zd = z $"($env.HOME)/Downloads"
    alias zp = z $"($env.HOME)/.dotfiles"
    
    # Search aliases
    alias search = rg --smart-case
    alias searchf = fd --type f
    alias searchd = fd --type d
  '';
}

