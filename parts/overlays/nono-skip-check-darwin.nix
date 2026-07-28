# nono's Darwin test suite currently includes a few path-sensitive tests that fail
# only inside the Nix build sandbox: `run --dry-run` coverage tests inherit HOME
# under `/nix/...`, `open_url_runtime` binds a Unix socket under a build path
# that exceeds `SUN_LEN` on Darwin, and `sandbox_state` round-trips a capability
# for a tempdir file whose `/tmp` -> `/private/tmp` canonicalization breaks under
# the build's TMPDIR. Skip only the affected tests; keep the rest of upstream
# coverage.
{ system }:
_final: prev:
let
  isDarwin = builtins.match ".*-darwin" system != null;
in
if !isDarwin then
  { }
else
  {
    llm-agents = prev.llm-agents // {
      nono = prev.llm-agents.nono.overrideAttrs (old: {
        checkFlags = (old.checkFlags or [ ]) ++ [
          "--skip=deprecated_override_deny_flag_emits_single_warning_on_stderr"
          "--skip=deprecated_override_deny_flag_warning_is_emitted_once_for_multiple_uses"
          "--skip=override_deny_alias_and_bypass_protection_merge_in_argv_order"
          "--skip=open_url_runtime::tests::test_open_url_helper_ipc_succeeds_when_supervisor_approves"
          "--skip=sandbox_state::tests::test_sandbox_state_roundtrip_preserves_source"
        ];
      });
    };
  }
