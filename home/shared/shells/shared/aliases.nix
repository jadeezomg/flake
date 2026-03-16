# Shared shell aliases used across all shells
{
  # Common aliases that work in all shells
  commonAliases = {
    # Replace default tools with better alternatives
    cat = "bat";
    find = "fd";
    grep = "rg";

    # eza
    ls = "eza --icons -l --git";
    l2 = "eza --icons -l -T -L=2";
    l3 = "eza --icons -l -T -L=3";
    llt = "eza --icons -T";
    lat = "eza --icons -Ta";
    tree = "eza --icons -Ta";
    lat1 = "eza --icons -Ta -L=1";
    lat2 = "eza --icons -Ta -L=2";
    lat3 = "eza --icons -Ta -L=3";
    lat4 = "eza --icons -Ta -L=4";
    lat5 = "eza --icons -Ta -L=5";

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
}
