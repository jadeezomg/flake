{
  programs.git.enable = true;
  programs.hunk = {
    enable = true;
    enableGitIntegration = true;
    settings = {
      theme = "auto";
      mode = "split";
      line_numbers = true;
      transparent_background = true;
    };
  };
}
