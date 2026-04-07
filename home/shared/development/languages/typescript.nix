{pkgs, ...}: {
  home.packages = with pkgs; [
    # --- TypeScript ---
    typescript # TypeScript compiler
    yarn-berry # Modern Yarn package manager (Berry)
    typescript-language-server # TypeScript language server
    biome # TypeScript linter and formatter
  ];
}
