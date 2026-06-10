{
  config,
  isDarwin,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dotfiles.profiles.apps.terminals;
in {
  config = lib.mkIf cfg.enable {
    # Linux-only (ghostty is broken on darwin in nixpkgs; terminal apps on
    # macOS come from homebrew / HM configs instead).
    environment.systemPackages = lib.optionals (!isDarwin) (with pkgs; [
      alacritty
      ghostty
      kitty
    ]);
  };
}
