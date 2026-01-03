{
  config,
  pkgs,
  ...
}: {
  imports = [];

  # Linux-specific shell configuration
  programs = {
    command-not-found.enable = false; # Required for fish
    nix-index = {
      enable = true;
      enableFishIntegration = true;
      # enableNushellIntegration = true; throws error?
    };
  };
}
