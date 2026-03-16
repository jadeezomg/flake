{pkgs, ...}: {
  home.packages = with pkgs; [
    # --- Javascript/Typescript/React.js/Next.js ---
    nodejs_24 # Node.js JavaScript runtime
    #nodejs_22
    #nodePackages.eslint
    # nodePackages.npm
    #  nodePackages.prettier
    # google-clasp
    bun
  ];
}
