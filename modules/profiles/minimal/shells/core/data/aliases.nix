{
  commonAliases = {
    cat = "bat";
    find = "fd";
    grep = "rg";

    ll = "eza --icons -l --git";
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

    ".." = "z ..";
    "..." = "z ../..";
    "...." = "z ../../..";
    "....." = "z ../../../..";

    zed = "zeditor";

    cl = "clear";
    h = "history";

    gst = "git status";
    gad = "git add .";
    gcm = "git commit -m";
    gpu = "git push -u origin main";

    search = "rg --smart-case";
    searchf = "fd --type f";
    searchd = "fd --type d";
  };
}
