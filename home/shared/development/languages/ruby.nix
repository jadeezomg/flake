{pkgs, ...}: {
  home.packages = with pkgs; [
    # --- Ruby Version Manager ---
    chruby # Ruby version manager
    ruby-install # Install Ruby versions
  ];
}

