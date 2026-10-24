{
  config,
  isDarwin,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.profiles.apps.notes;
in
{
  config = lib.mkIf cfg.enable (
    {
      environment.systemPackages = lib.optionals (!isDarwin) [ pkgs.typora ];

      home-manager.sharedModules = [
        (
          { config, ... }:
          {
            xdg.configFile."Typora/themes/birds-of-paradise.css".text = import ./theme.nix {
              inherit (config.dotfiles.theme) palette;
            };
          }
        )
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
