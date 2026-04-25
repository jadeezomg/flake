{pkgs, ...}: let
  # home-manager's programs.navi module only supports bash/zsh/fish.
  # For nushell we source the widget output directly so Ctrl-G opens navi.
  naviNushellWidget = pkgs.runCommand "navi-widget.nu" {} ''
    ${pkgs.navi}/bin/navi widget nushell > $out
  '';
in {
  programs = {
    btop = {
      enable = true;
      settings = {
        theme_background = false;
      };
    };

    broot = {
      enable = true;
      enableFishIntegration = true;
      enableNushellIntegration = true;
    };

    zoxide = {
      enable = true;
      enableFishIntegration = true;
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
      # enableFishIntegration and enableNushellIntegration are automatically enabled
      # when programs.fish.enable or programs.nushell.enable are set
      nix-direnv.enable = true;
    };

    yazi = {
      enable = true;
      shellWrapperName = "y";
      settings = {
        mgr = {
          ratio = [3 3 4];
          show_hidden = true;
          show_symlink = true;
          linemode = "size_and_mtime";
        };
      };
    };
  };
}
