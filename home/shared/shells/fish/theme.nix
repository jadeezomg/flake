{
  config,
  pkgs,
  ...
}: let
  sharedConfig = import ../shared/config.nix;
in {
  # Configure Oh My Posh for Fish
  programs.fish.interactiveShellInit = ''
    ${pkgs.oh-my-posh}/bin/oh-my-posh init fish --config ${sharedConfig.ohMyPoshConfig.themePath} | source
  '';
}
