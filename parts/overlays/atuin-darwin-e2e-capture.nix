# atuin's e2e_capture test `filtered_commands_leave_no_captured_output` times
# out in the Darwin build sandbox ("timed out waiting for the last command's
# captured output; captured: []"). In e2e_pty, every test with the
# bash_preexec shell setup fails too (13 of 85); the other setups pass. Hydra
# has no aarch64-darwin build of atuin 18.23.0. The Linux build is cached, so
# this overlay only applies on Darwin.
#
# Verified 2026-10-14 against atuin 18.23.0 on aarch64-darwin.
{
  expiry,
  lib,
  system,
}:
_final: prev:
if builtins.match ".*-darwin" system == null then
  { }
else
  {
    atuin =
      expiry.recheckWhen
        {
          stale = lib.versionAtLeast prev.atuin.version "18.26";
          reason = "atuin reached 18.26 (skip verified needed at 18.23.0); check whether nixpkgs atuin is cached for darwin (nix path-info --store https://cache.nixos.org on its outPath) and drop the overlay if it is.";
        }
        (
          prev.atuin.overrideAttrs (old: {
            checkFlags = (old.checkFlags or [ ]) ++ [
              "--skip=filtered_commands_leave_no_captured_output"
              "--skip=bash_preexec"
            ];
          })
        );
  }
