# dsh (DeepSeek Harness) aborts at boot on Nix-built Node.js:
#   dsh: host preparation failed: node-addon-require-builtin unsupported:
#   Unsupported/no-getter (arm64 getter is not optional-bti-ldr-x0-this-imm-ret)
# The node-addon-require-builtin addon scans the node binary for a known
# machine-code pattern. nixpkgs builds node with zerocallusedregs hardening,
# which changes that pattern, so the scan fails. The official nodejs.org binary
# works. This overlay keeps the upstream dsh package and only swaps the node
# binary in its wrapper for the official one.
#   https://github.com/NixOS/nixpkgs/issues/565667
#   https://github.com/numtide/llm-agents.nix/issues/9994
#
# Verified 2026-09-29 against dsh 0.1.7-rc.2 and node 24.20.0 on aarch64-darwin.
{
  expiry,
  lib,
  system,
}:
let
  nodeVersion = "24.20.0";
in
_final: prev:
if system != "aarch64-darwin" then
  { }
else
  {
    llm-agents = prev.llm-agents // {
      dsh =
        let
          dsh = prev.llm-agents.dsh;
          nodeTarball = prev.fetchurl {
            url = "https://nodejs.org/dist/v${nodeVersion}/node-v${nodeVersion}-darwin-arm64.tar.xz";
            hash = "sha256-t793BwcLlQuh7F8a87tt4PKxlixQM5c9lAaKsCHvMBQ=";
          };
          wrapped =
            prev.runCommand "dsh-${dsh.version}"
              {
                nativeBuildInputs = [ prev.makeWrapper ];
                inherit (dsh) version meta;
              }
              ''
                mkdir -p $out/libexec
                tar -xJf ${nodeTarball} -C $out/libexec --strip-components=2 node-v${nodeVersion}-darwin-arm64/bin/node
                makeWrapper $out/libexec/node $out/bin/dsh \
                  --argv0 dsh \
                  --add-flags "--expose-internals" \
                  --add-flags "${dsh}/lib/node_modules/@deepseek-ai/dsh/lib/bin.js"
              '';
        in
        expiry.expireWhen
          {
            fixed = lib.elem "zerocallusedregs" (prev.nodejs.hardeningDisable or [ ]);
            reason = "nixpkgs nodejs now disables zerocallusedregs (NixOS/nixpkgs#565667).";
            fallback = dsh;
          }
          (
            expiry.recheckWhen {
              stale = lib.versionAtLeast dsh.version "0.1.8";
              reason = "dsh reached 0.1.8 (verified broken at 0.1.7-rc.2); retest with Nix node.";
            } wrapped
          );
    };
  }
