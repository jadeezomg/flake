{...}: {
  programs = {
    pay-respects = {
      enable = true;
      enableFishIntegration = true;
      enableNushellIntegration = true;
    };

    zoxide = {
      enable = true;
      enableFishIntegration = true;
      enableNushellIntegration = true;
    };

    direnv = {
      enable = true;
      # enableFishIntegration and enableNushellIntegration are automatically enabled
      # when programs.fish.enable or programs.nushell.enable are set
      nix-direnv.enable = true;
    };

    yazi = {
      enable = true;
    };
  };
}
