{pkgs, ...}: {
  home.packages = with pkgs; [
    # --- Ruby ---
    ruby # Install Ruby versions

    # NOTE: chruby is now installed via Homebrew on macOS
    # for better bash/zsh compatibility
  ];
}
