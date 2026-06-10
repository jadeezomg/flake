# Home-manager options for paths into the live dotfiles checkout (out-of-store
# symlinks, shell helpers, etc.). Override `dotfiles.flakeRoot` if the flake
# lives somewhere other than ~/.dotfiles/flake.
{
  config,
  lib,
  ...
}: {
  options.dotfiles.flakeRoot = lib.mkOption {
    type = lib.types.str;
    description = ''
      Absolute path to the flake directory on disk (the directory that contains
      `flake.nix`). Used for `mkOutOfStoreSymlink` targets and shell `FLAKE` /
      `NH_FLAKE`. Defaults to ~/.dotfiles/flake.
    '';
  };

  config = {
    dotfiles.flakeRoot = lib.mkDefault "${config.home.homeDirectory}/.dotfiles/flake";

    # HM-native helper channel: any HM module can use
    # `config.lib.dotfiles.mkLiveSymlink` & friends without path imports
    # (same mechanism as config.lib.file.mkOutOfStoreSymlink).
    lib.dotfiles = import ./live-xdg-symlinks.nix {inherit config;};
  };
}
