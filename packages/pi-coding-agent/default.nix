{
  pkgs,
  lib,
  ...
}:
pkgs.buildNpmPackage rec {
  pname = "pi-coding-agent";
  version = "0.68.0";

  # Published bundle (includes dist/); newer than nixpkgs @mariozechner/pi-coding-agent.
  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@mariozechner/pi-coding-agent/-/pi-coding-agent-0.68.0.tgz";
    hash = "sha256-WFbinveteUJx+0ZtAz7BRC4WE2kKl2dBb70yJSQyGyU=";
  };

  # Generated: unpack tgz, cd package, npm install --package-lock-only
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-/+x5IvFY9bXMGvXxD8OJzHHTBnsVLvADgtz2vCjCu2Q=";

  dontNpmBuild = true;

  meta = with lib; {
    description = "Pi terminal coding agent (npm @mariozechner/pi-coding-agent)";
    homepage = "https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent";
    license = licenses.mit;
    mainProgram = "pi";
  };
}
