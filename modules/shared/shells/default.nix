{pkgs, ...}: {
  environment.shells = with pkgs; [
    bash
    fish
    nushell
  ];

  programs = {
    bash.completion.enable = true; # Required for home setting
    fish.enable = true;
  };
}
