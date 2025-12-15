{ pkgs, ... }:
{
  imports = [
    ./cursor
  ];

  home.packages = with pkgs; [
    code-cursor
  ];
}
