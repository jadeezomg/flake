{
  pkgs,
  lib,
  ...
}:
pkgs.buildNpmPackage rec {
  pname = "pi-coding-agent";
  version = "0.70.0";

  # Published bundle (includes dist/); newer than nixpkgs @mariozechner/pi-coding-agent.
  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@mariozechner/pi-coding-agent/-/pi-coding-agent-0.70.0.tgz";
    hash = "sha256-i3boU7lwtuc67VphIq4L0SZSg/V+v5KgOlNgGdmjAXc=";
  };

  # Generated: unpack tgz, cd package, npm install --package-lock-only
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-3VF1JdASdRf5vcjRSQDY3Rpu/oSO4PvIumnZohpWTGE=";

  dontNpmBuild = true;

  meta = with lib; {
    description = "Pi terminal coding agent (npm @mariozechner/pi-coding-agent)";
    homepage = "https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent";
    license = licenses.mit;
    mainProgram = "pi";
  };
}
