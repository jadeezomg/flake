{pkgs, ...}: {
  home.packages = with pkgs; [
    # --- TypeScript ---
    nodePackages.typescript # TypeScript compiler
    yarn-berry # Modern Yarn package manager (Berry)
    nodePackages.typescript-language-server # TypeScript language server
  ];
}
