{
  pkgs,
  lib,
  ...
}: let
  unwrapped = pkgs.buildNpmPackage rec {
    pname = "pi-coding-agent-unwrapped";
    version = "0.72.1";

    # Published bundle (includes dist/); newer than nixpkgs @mariozechner/pi-coding-agent.
    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/@mariozechner/pi-coding-agent/-/pi-coding-agent-0.72.1.tgz";
      hash = "sha256-lyvT1SyvfsQe2a5m71Hf+awOo7CPVNRwvSf3TCcWeUY=";
    };

    # Generated: unpack tgz, cd package, npm install --package-lock-only
    postPatch = ''
      cp ${./package-lock.json} package-lock.json
    '';

    npmDepsHash = "sha256-LgUAG0c7xaGnkyQ4q5aqvl5vsWSesQM+tMGKkyWweQ8=";

    dontNpmBuild = true;

    meta = with lib; {
      description = "Pi terminal coding agent (npm @mariozechner/pi-coding-agent)";
      homepage = "https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent";
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
