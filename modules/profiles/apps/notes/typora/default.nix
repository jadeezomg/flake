{
  config,
  dotfilesLib,
  isDarwin,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.profiles.apps.notes;
  typoraTheme = import ./theme.nix {
    inherit (dotfilesLib) palette;
  };
in
{
  config = lib.mkIf cfg.enable (
    {
      environment.systemPackages = lib.optionals (!isDarwin) [ pkgs.typora ];

      home-manager.sharedModules = [
        {
          xdg.configFile."Typora/themes/birds-of-paradise.css".text = typoraTheme;
        }
      ];
    }
    # Claim the markdown role in the desktop MIME table (desktop/mime.nix).
    # Priority 900 beats the mkDefault baseline there and still loses to a plain
    # host assignment. The option only exists on Linux, so darwin skips it.
    // lib.optionalAttrs (!isDarwin) {
      dotfiles.desktop.mimeHandlers.markdown = lib.mkOverride 900 "typora";
    }
  );
}
