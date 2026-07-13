{ pkgs, ... }: {
  home.packages = with pkgs; [
    # --- Prisma ---
    prisma # Prisma CLI
    prisma-engines
  ];
}
