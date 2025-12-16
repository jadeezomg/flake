{pkgs, ...}: {
  home.packages = with pkgs; [
    # --- Prisma ---
    # nodePackages.prisma # Prisma CLI  # Temporarily disabled due to Node.js conflicts
    prisma-engines
  ];
}
