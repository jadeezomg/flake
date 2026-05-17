{
  pkgs,
  lib,
  ...
}: let
  unwrapped = pkgs.buildNpmPackage {
    pname = "pi-coding-agent-unwrapped";
    version = "0.75.0";

    # Published bundle (includes dist/). Upstream moved from @mariozechner to @earendil-works.
    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-0.75.0.tgz";
      hash = "sha256-C/BNcf/BZpw4GpiOt4bnd/8dHgl5jnb1nbItr2xMLz0=";
    };

    # Generated: unpack tgz, cd package, npm install --package-lock-only
    postPatch = ''
      cp ${./package-lock.json} package-lock.json
    '';

    npmDepsHash = "sha256-QGYGlSv3aDSLUv2b3wGFEaFUcRpHMvFDMasa2PzJXXg=";

    dontNpmBuild = true;

    meta = with lib; {
      description = "Pi terminal coding agent (npm @earendil-works/pi-coding-agent)";
      homepage = "https://github.com/earendil-works/pi/tree/main/packages/coding-agent";
      license = licenses.mit;
      mainProgram = "pi";
    };
  };
in
  # Wrap pi so npm install -g (used by `pi install npm:…`) writes to
  # ~/.npm-global instead of trying to mkdir in the read-only nix store.
  #
  # Also scrub `npm_*` / `npm_config_*` env vars inherited from ancestor
  # processes (Zed and Claude Code launch their child shells inside an npm
  # exec context, which sets `npm_config_prefix` / `npm_config_globalconfig`
  # pointing at editor-managed paths). Those lowercase env vars take
  # precedence over `NPM_CONFIG_PREFIX`, so without scrubbing them pi's
  # `npm install -g` would silently write bin symlinks to the wrong prefix
  # (or skip them entirely).
  pkgs.symlinkJoin {
    name = "pi-coding-agent";
    paths = [unwrapped];
    buildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/pi \
        --run 'for _v in $(${pkgs.coreutils}/bin/env | ${pkgs.gnused}/bin/sed -n "s/^\(npm_[a-zA-Z_][a-zA-Z0-9_]*\)=.*/\1/p"); do unset "$_v"; done; export NPM_CONFIG_PREFIX="''${NPM_CONFIG_PREFIX:-$HOME/.npm-global}"'
    '';
    meta = unwrapped.meta;
  }
