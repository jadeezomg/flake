{ pkgs, ... }:
let
  # home-manager's programs.navi module only supports bash/zsh.
  # For nushell we source the widget output directly so Ctrl-G opens navi.
  naviNushellWidget = pkgs.runCommand "navi-widget.nu" { } ''
    ${pkgs.navi}/bin/navi widget nushell > $out
  '';
in
{
  programs = {
    btop = {
      enable = true;
      settings = {
        theme_background = false;
      };
    };

    broot = {
      enable = true;
      enableNushellIntegration = true;
    };

    zoxide = {
      enable = true;
      enableNushellIntegration = true;
    };

    navi = {
      enable = true;
      enableBashIntegration = true;
    };

    nushell.extraConfig = ''
      source ${naviNushellWidget}
    '';

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}
