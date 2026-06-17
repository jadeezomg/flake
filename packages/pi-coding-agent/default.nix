{
  pkgs,
  lib,
  ...
}: let
  unwrapped = pkgs.buildNpmPackage rec {
    pname = "pi-coding-agent-unwrapped";
<<<<<<< HEAD
    version = "0.79.6";

    # Published bundle (includes dist/). Upstream moved from @mariozechner to @earendil-works.
    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-0.79.6.tgz";
      hash = "sha256-9aKUHM6mivSUYrIomOqplotcHskA263sCOJbman2C8I=";
=======
    version = "0.79.3";

    # Published bundle (includes dist/). Upstream moved from @mariozechner to @earendil-works.
    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-0.79.3.tgz";
      hash = "sha256-+yjLrpqRvHo+dnKVBCdl/X4mIYPK50LwHAx0sgyN4yg=";
>>>>>>> 84c4a091f50c5e6bb8af7a4f76a9d96ae4676728
    };

    # Generated: unpack tgz, cd package, npm install --package-lock-only
    # Both files are written: buildNpmPackage prefers npm-shrinkwrap.json when
    # both exist, and the tarball ships one without integrity hashes.
    postPatch = ''
      cp ${./package-lock.json} package-lock.json
      cp ${./package-lock.json} npm-shrinkwrap.json
    '';

<<<<<<< HEAD
    npmDepsHash = "sha256-LwCK4oGy+RWTj8zqpAmIkNdfcfZ1vZ2XhYamYjiz1vQ=";
=======
    npmDepsHash = "sha256-haO4mDQ24ACKL/BoJUSbD8mcWkqDxq5jsKAmm4DCcKc=";
>>>>>>> 84c4a091f50c5e6bb8af7a4f76a9d96ae4676728

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
