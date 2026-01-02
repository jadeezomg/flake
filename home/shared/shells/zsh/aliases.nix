{
  config,
  pkgs,
  ...
}: let
  sharedAliases = import ../shared/aliases.nix;
in {
  # Import common aliases from shared configuration
  programs.zsh.shellAliases = sharedAliases.commonAliases;
}
