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
      enableFishIntegration = true;
      enableNushellIntegration = true;
      nix-direnv.enable = true;
    };

    yazi = {
      enable = true;
    };
  };
}
