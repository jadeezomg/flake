{...}: {
  programs.atuin = {
    enable = true;
    # enableBashIntegration, enableFishIntegration, enableNushellIntegration,
    # enableZshIntegration all default to true
  };
}
