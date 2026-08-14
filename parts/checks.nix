# Flake checks + formatter. Eval-level only — no VM tests, nothing builds
# beyond trivial runCommand stamps.
{
  inputs,
  lib,
  self,
  ...
}:
{
  perSystem =
    {
      pkgs,
      system,
      ...
    }:
    {
      checks = {
        agent-skills =
          let
            testPassed = import ../tests/agent-skills.nix { inherit lib inputs; };
          in
          assert testPassed;
          pkgs.runCommand "agent-skills-tests" { } ''
            touch "$out"
          '';

        mcp-servers =
          let
            testPassed = import ../tests/mcp-servers.nix { inherit (pkgs) lib; };
          in
          assert testPassed;
          pkgs.runCommand "mcp-servers-tests" { } ''
            touch "$out"
          '';
      }
      // lib.optionalAttrs (system == "aarch64-darwin") {
        # `nix flake check` evaluates nixosConfigurations but ignores
        # darwinConfigurations — force the darwin host eval here so caya
        # regressions fail the check. Eval-only: the drvPath's string context
        # is discarded, so nothing is built.
        host-caya-eval = pkgs.runCommand "host-caya-eval" { } ''
          echo "${builtins.unsafeDiscardStringContext self.darwinConfigurations.caya.config.system.build.toplevel.drvPath}" > "$out"
        '';
      }
      // lib.optionalAttrs (system == "x86_64-linux") {
        # Server-class host stays headless: desktop-flavored module content
        # must not leak onto mini even though the modules are imported for
        # every Linux host.
        host-mini-headless =
          let
            cfg = self.nixosConfigurations.mini.config;
          in
          assert !cfg.programs.niri.enable;
          assert !cfg.programs.steam.enable;
          assert !cfg.services.flatpak.enable;
          pkgs.runCommand "host-mini-headless" { } ''
            touch "$out"
          '';
      };

      formatter = pkgs.nixfmt-tree;
    };
}
