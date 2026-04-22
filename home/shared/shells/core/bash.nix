{...}: let
  aliases = (import ./data/aliases.nix).commonAliases;
  paths = (import ./data/paths.nix).commonPaths;
in {
  programs.bash = {
    enable = true;
    shellAliases = aliases;

    initExtra = ''
      zz() { cd ${paths.home}; }
      zc() { cd ${paths.config}; }
      zd() { cd ${paths.downloads}; }
    '';
  };
}
