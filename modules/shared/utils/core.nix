{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Core utilities
    eza # Better ls
    fd # Better find
    dust # Better disk usage
    broot # Interactive tree view
    difftastic # Better diff
  ];
}
