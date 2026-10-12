# Noctalia Greeter on greetd. The nixpkgs module also enables greetd,
# AccountsService (avatars), and polkit with pkexec.
# Docs: https://docs.noctalia.dev/greeter/
{
  config,
  lib,
  pkgs,
  user,
  ...
}:
let
  cfg = config.dotfiles.profiles.desktop;
in
{
  config = lib.mkIf (cfg.enable && cfg.loginManager == "noctalia-greeter") {
    services.displayManager.noctalia-greeter = {
      enable = true;
      # Noctalia's "Auto-Sync Greeter" copies wallpaper, palette, font, and
      # monitor layout to the greeter. This lets it sync without a password.
      passwordlessSyncUsers = [ user ];
      # The greeter is its own compositor and does not read niri's input config.
      settings.keyboard = {
        inherit (config.services.xserver.xkb) layout variant;
      };
      # Same cursor as the session (HM stylix in modules/profiles/theme/gui.nix).
      cursorTheme = {
        package = pkgs.phinger-cursors;
        name = "phinger-cursors-dark";
      };
    };
  };
}
