# dsh boots a HMR service to watch its profile patch files, and that service
# reads Node internal ESM loader state. The check is
# `process.execArgv.includes('--expose-internals')`, so the flag must be on the
# node command line. NODE_OPTIONS cannot carry it — node rejects
# `--expose-internals` in NODE_OPTIONS.
#
# The upstream wrapper (packages/dsh/package.nix in numtide/llm-agents.nix)
# calls `makeWrapper node $out/bin/dsh --add-flags "$out/lib/dsh/lib/bin.js"`
# and adds no node flags, so every profile dies at boot with
# "failed to apply loader entry … --expose-internals is required for HMR
# service". Verified 2026-08-15 against dsh 0.1.0-rc.6: `dsh --profile web`
# fails, and the same command with the flag starts the server.
{ expiry, lib }:
_final: prev: {
  # `mkPackagesFor` returns a plain attrset, not a scope, so there is no
  # `overrideScope` to go through.
  llm-agents = prev.llm-agents // {
    dsh =
      expiry.expireWhen
        {
          fixed = lib.hasInfix "--expose-internals" (prev.llm-agents.dsh.installPhase or "");
          reason = "the llm-agents.nix dsh wrapper already passes --expose-internals to node.";
          fallback = prev.llm-agents.dsh;
        }
        (
          prev.llm-agents.dsh.overrideAttrs (old: {
            postInstall = (old.postInstall or "") + ''
              substituteInPlace $out/bin/dsh \
                --replace-fail "$out/lib/dsh/lib/bin.js" "--expose-internals $out/lib/dsh/lib/bin.js"
            '';
          })
        );
  };
}
