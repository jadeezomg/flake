{pkgs, ...}: {
  home.packages = with pkgs; [
    # --- Graphql (as Nodepackage) ---
    graphql-language-service-cli
  ];
}
