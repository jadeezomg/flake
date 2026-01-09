{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # --- Task Runners ---
    just # Handy way to save and run project-specific commands
    mask # CLI task runner defined by a simple markdown file
    act # Run GitHub Actions locally

    # --- Git Tools ---
    gh # GitHub CLI
    delta # Better git diff viewer
    lazygit # Terminal UI for git

    # --- Code Metrics & Analysis ---
    tokei # Code metrics

    # --- Package Managers ---
    uv # Python package manager

    # --- Nix Tools ---
    nixfmt # Nix formatter
    nil # Nix language server
    nixd # Alternative Nix language server
  ];
}
