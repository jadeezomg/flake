{
  pkgs,
  lib,
  isDarwin,
  ...
}: {
  config = lib.mkMerge (
    [
      {
        environment.shells = with pkgs; [
          bash
          fish
          nushell
        ];

        programs = {
          bash.completion.enable = true;
          fish.enable = true;
        };
      }
    ]
    ++ lib.optionals (!isDarwin) [
      {
        # /bin/bash compat for scripts with hardcoded shebangs (third-party tools)
        environment.binsh = "${pkgs.bash}/bin/bash";

        programs = {
          command-not-found.enable = false; # Required for fish
          nix-index = {
            enable = true;
            enableFishIntegration = true;
          };
        };

        # Shell history sync across shells; service-style on NixOS only.
        services.atuin.enable = true;
      }
    ]
  );
}
