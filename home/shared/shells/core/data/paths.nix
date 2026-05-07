{
  # Generic per-user directories. Sandbox-safe — these reference $HOME but
  # never the dotfiles repo path. cd shortcuts that need $HOME/.dotfiles
  # land in env/system.nix together with the other system-only refs.
  commonPaths = {
    home = "$HOME";
    config = "$HOME/.config";
    downloads = "$HOME/Downloads";
    localBin = "$HOME/.local/bin";
    cargoBin = "$HOME/.cargo/bin";
    npmGlobalBin = "$HOME/.npm-global/bin";
  };

  # PATH segments in canonical order. Wrappers must stay first so setuid
  # binaries like sudo continue to work.
  nixPaths = {
    wrappersBin = "/run/wrappers/bin";
    nixProfile = "$HOME/.nix-profile/bin";
    userProfile = "/etc/profiles/per-user/$USER/bin";
    systemSw = "/run/current-system/sw/bin";
    defaultProfile = "/nix/var/nix/profiles/default/bin";
  };
}
