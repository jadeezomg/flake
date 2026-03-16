{pkgs, ...}: {
  environment.shells = with pkgs; [
    bash
    fish
    nushell
  ];

  programs = {
    bash.completion.enable = true;
    fish.enable = true;
  };
}
