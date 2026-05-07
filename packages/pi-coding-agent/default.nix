{
  pkgs,
  lib,
  ...
}: let
  unwrapped = pkgs.buildNpmPackage rec {
    pname = "pi-coding-agent-unwrapped";
    version = "0.74.0";

    # Published bundle (includes dist/). Upstream moved from @mariozechner to @earendil-works.
    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-0.74.0.tgz";
      hash = "sha256-l0pzuWGVvX1jDhFYaey14N16XDo47kkm3JlEhmPUo0Q=";
    };

    # Generated: unpack tgz, cd package, npm install --package-lock-only
    postPatch = ''
      cp ${./package-lock.json} package-lock.json
    '';

    npmDepsHash = "sha256-lkF4GyXWzVl9vy/VHFkwwbuDbtAVJGtMNRtT0KJ6vZo=";

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
  pkgs.symlinkJoin {
    name = "pi-coding-agent";
    paths = [unwrapped];
    buildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/pi \
        --run 'export NPM_CONFIG_PREFIX="''${NPM_CONFIG_PREFIX:-$HOME/.npm-global}"'
    '';
    meta = unwrapped.meta;
  }
