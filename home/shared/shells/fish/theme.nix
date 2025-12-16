{
  config,
  pkgs,
  ...
}: {
  # Configure Oh My Posh for Fish
  programs.fish.interactiveShellInit = ''
    ${pkgs.oh-my-posh}/bin/oh-my-posh init fish --config "$HOME/.config/oh-my-posh/birds-of-paradise.json" | source
  '';
}
