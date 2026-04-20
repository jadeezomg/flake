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
  # Atuin is a shell history management tool that works across shells
  services.atuin.enable = true;
}
