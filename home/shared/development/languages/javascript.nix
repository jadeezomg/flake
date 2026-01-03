{pkgs, ...}: {
  home.packages = with pkgs; [
    # --- Javascript/Typescript/React.js/Next.js ---
    # nodejs # Node.js JavaScript runtime
    #nodejs_22
    #nodePackages.eslint
    # nodePackages.npm
    #  nodePackages.prettier
    #biome
  ];
}
