# netwatch's `parser_layer_leaves_fast_open_and_autobind_open` asserts that a
# sendto(MSG_FASTOPEN) still succeeds inside a Landlock sandbox, but current
# kernels apply the sandbox's TCP rules to that call too, so it returns EACCES
# and the suite fails at src/sandbox/linux.rs:1487:
#
#   assertion `left == right` failed
#     left: Err(EACCES)
#    right: Ok(9)
#
# The test only runs when net.ipv4.tcp_fastopen has the client bit set, which it
# does here. Nothing about it depends on the flake; the package itself is fine
# to build and run, so skip the one test instead of the whole suite.
#
# Verified 2026-11-11 against netwatch-tui 0.39.0 on linux 7.3.1-cachyos.
{
  expiry,
  lib,
  system,
}:
let
  isLinux = lib.hasInfix "-linux" system;
  test = "sandbox::linux::tests::parser_layer_leaves_fast_open_and_autobind_open";
in
_final: prev:
if !isLinux then
  { }
else
  {
    # Attribute name is the directory name, `netwatch`; pname is netwatch-tui.
    netwatch =
      expiry.recheckWhen
        {
          stale = lib.versionAtLeast prev.netwatch.version "0.42";
          reason = "netwatch reached 0.42; check whether the Landlock MSG_FASTOPEN test was fixed or skipped upstream.";
        }
        (
          prev.netwatch.overrideAttrs (old: {
            checkFlags = (old.checkFlags or [ ]) ++ [ "--skip=${test}" ];
          })
        );
  }
