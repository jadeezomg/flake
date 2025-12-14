{ pkgs, ... }:

{
  environment.shells = with pkgs; [
    bash
    fish
    nushell
  ];

  programs = {
    bash.completion.enable = true; # Required for home setting
    fish.enable = true;
    command-not-found.enable = false; # Required for fish
  };

  programs.nix-index = {
    enable = true;
    enableFishIntegration = true;
    # enableNushellIntegration = true; throws error?
  };
}
