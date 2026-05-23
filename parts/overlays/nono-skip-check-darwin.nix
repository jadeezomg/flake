# nono's Darwin test suite currently includes a few `run --dry-run` coverage tests
# that inherit HOME under `/nix/...` inside the Nix build sandbox. nono protects
# `~/.nono`, and the default macOS `system_read_macos` group grants `/nix`, so
# those build-only tests fail before exercising the deprecated-flag behavior.
# Skip only the affected tests on Darwin; keep the rest of upstream coverage.
{system}: _final: prev: let
  isDarwin = builtins.match ".*-darwin" system != null;
in
  if !isDarwin
  then {}
  else {
    nono = prev.nono.overrideAttrs (old: {
      checkFlags =
        (old.checkFlags or [])
        ++ [
          "--skip=deprecated_override_deny_flag_emits_single_warning_on_stderr"
          "--skip=deprecated_override_deny_flag_warning_is_emitted_once_for_multiple_uses"
          "--skip=override_deny_alias_and_bypass_protection_merge_in_argv_order"
        ];
    });
  }
