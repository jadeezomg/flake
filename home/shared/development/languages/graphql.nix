{pkgs, ...}: {
  home.packages = with pkgs; [
    # --- Graphql ---
    graphql-language-service-cli
  ];
}
