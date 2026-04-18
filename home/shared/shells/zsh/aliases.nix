{...}: let
  sharedAliases = import ../shared/aliases.nix;
  sharedPaths = import ../shared/paths.nix;
in {
  programs.zsh.shellAliases = sharedAliases.commonAliases;
  programs.zsh.initContent = ''
    zz() { cd ${sharedPaths.commonPaths.home}; }
    zc() { cd ${sharedPaths.commonPaths.config}; }
    zd() { cd ${sharedPaths.commonPaths.downloads}; }
    zp() { cd ${sharedPaths.commonPaths.dotfiles}; }
    zf() { cd ${sharedPaths.commonPaths.flake}; }
  '';
}
