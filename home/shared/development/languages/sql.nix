{pkgs, ...}: {
  home.packages = with pkgs; [
    # --- Sql ---
    # sqlfluff # TEMPORARILY DISABLED - dependency conflict with click version
    sqlite # SQLite database
    sqls # SQL language server
  ];
}
