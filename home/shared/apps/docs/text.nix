{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # * maybe try at some point
    # anytype
    # * oos notion alternative
    # appflowy
    # * privacy-first, open-source platform for knowledge management and collaboration
    # logseq
    # * open-source note-taking app
    obsidian

  ];

  programs.zathura = {
    enable = true;
  };
}
