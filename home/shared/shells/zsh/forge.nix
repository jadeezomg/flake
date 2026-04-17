{
  inputs,
  lib,
  pkgs,
  ...
}: let
  forgePkg = inputs.forgecode.packages.${pkgs.stdenv.hostPlatform.system}.default;
in {
  # https://github.com/tailcallhq/forgecode/tree/main/shell-plugin
  home.sessionVariables.FORGE_BIN = lib.getExe forgePkg;
  programs.zsh.initContent = ''
    if [[ -r "${inputs.forgecode}/shell-plugin/forge.plugin.zsh" ]]; then
      source "${inputs.forgecode}/shell-plugin/forge.plugin.zsh"
    fi
  '';
}
