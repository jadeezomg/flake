{
  pkgs,
  lib,
  ...
}: let
  unwrapped = pkgs.buildNpmPackage rec {
    pname = "pi-coding-agent-unwrapped";
    version = "0.78.1";

    # Published bundle (includes dist/). Upstream moved from @mariozechner to @earendil-works.
    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-0.78.1.tgz";
      hash = "sha256-72mCHDg9kv0n59mtvcseN2IUQelMUjSOR6KQHqnX3Qw=";
    };

    # Generated: unpack tgz, cd package, npm install --package-lock-only
    # Both files are written: buildNpmPackage prefers npm-shrinkwrap.json when
    # both exist, and the tarball ships one without integrity hashes.
    postPatch = ''
      cp ${./package-lock.json} package-lock.json
      cp ${./package-lock.json} npm-shrinkwrap.json
    '';

    npmDepsHash = "sha256-UQgzKdmIX1mLctNtF/BTYLasYYt8bvfa3elIZjE9uGI=";

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
