{
  # Documentation for the cd shortcut family. Each shell in core/<shell>.nix
  # implements zz/zc/zd in its native syntax. Shortcuts that depend on the
  # dotfiles repo path (zp, zf, flake, nuflake) live in env/system.nix and
  # are only wired when essentials.enable = true.
  commonFunctions = {
    zz = {
      description = "cd to home";
      path = "$HOME";
    };
    zc = {
      description = "cd to config";
      path = "$HOME/.config";
    };
    zd = {
      description = "cd to downloads";
      path = "$HOME/Downloads";
    };
  };
}
