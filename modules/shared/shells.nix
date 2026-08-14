{ pkgs, ... }: {
  environment.shells = with pkgs; [
    bash
    nushell
  ];

  programs = {
    bash.completion.enable = true;
  };
}
