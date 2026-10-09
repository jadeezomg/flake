# Core dev tooling — the system packages plus the HM half (mise).
{ dotfilesLib, ... }@args:
dotfilesLib.mkProfile {
  path = [ "devenv" ];
  # mise — polyglot tool/runtime version manager and task runner. mise is
  # inside the nix closure on both platforms, so home-manager generates the
  # shell activation snippets at build time. nushell gets a store path it can
  # `use`, which is why the writable-cache dance the Homebrew mise needed on
  # Darwin is gone.
  hm = [
    (
      { lib, pkgs, ... }:
      {
        programs.mise = {
          enable = true;
          # mise >= 2026.9 `activate nu` writes the PATH of the shell that runs
          # it into the script. Home Manager runs it in the build sandbox, so
          # every nu login got the sandbox PATH without /run/current-system/sw/bin.
          # GDM starts the session through the login shell, so niri-session did
          # not find systemctl and the login went back to the greeter. We make
          # the script ourselves and remove the two PATH lines.
          enableNushellIntegration = false;
        };
        programs.nushell.extraConfig =
          (dotfilesLib.expiry { inherit lib; } "modules/profiles/devenv/tools.nix").recheckWhen
            {
              stale = lib.versionAtLeast pkgs.mise.version "2027.1";
              reason = "mise reached 2027.1 (baked PATH seen at 2026.9.18); check if `mise activate nu` still writes $env.PATH / __MISE_ORIG_PATH, and go back to enableNushellIntegration if not.";
            }
            ''
              use ${
                pkgs.runCommand "mise-nushell-config.nu" { } ''
                  ${lib.getExe pkgs.mise} activate nu \
                    | grep -v -E "^\s*[$]env[.](__MISE_ORIG_PATH|PATH) = [(]?r#'" > $out
                  ! grep -q "r#'" $out
                ''
              }
            '';
      }
    )
  ];

  packages =
    pkgs: with pkgs; [
      # --- Build essentials (migrated from modules/shared/utils/core.nix) ---
      gnumake
      gcc
      gdb
      pkg-config

      # --- Version control ---
      jujutsu
      jjui
      gh
      lazygit
      gh-dash

      # --- Task runners ---
      just
      act
      watchexec

      # --- Code metrics & analysis ---
      tokei
      diffnav

      # --- Session recording ---
      asciinema
    ];
} args
