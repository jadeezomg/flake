{pkgs, ...}: {
  home.packages = with pkgs; [
    # --- Graphql (as Nodepackage) ---
    # nodePackages.graphql-language-service-cli  # Temporarily disabled due to Node.js conflicts
  ];
}
