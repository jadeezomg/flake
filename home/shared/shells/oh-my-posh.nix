{
  config,
  pkgs,
  ...
}: {
  # Install custom Birds of Paradise Oh My Posh theme (shared across all shells)
  home.file.".config/oh-my-posh/birds-of-paradise.json" = {
    source = ../../assets/theme/birds-of-paradise-posh.json;
  };

  # Configure Oh My Posh for Bash
  # This will merge with existing bash configuration if present
  programs.bash.initExtra = ''
    eval "$(${pkgs.oh-my-posh}/bin/oh-my-posh init bash --config "$HOME/.config/oh-my-posh/birds-of-paradise.json")"
  '';

  # Configure Oh My Posh for Fish
  # This will merge with existing fish configuration if present
  programs.fish.interactiveShellInit = ''
    oh-my-posh init fish --config "$HOME/.config/oh-my-posh/birds-of-paradise.json" | source
  '';
}
