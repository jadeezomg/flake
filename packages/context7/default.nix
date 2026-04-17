{
  pkgs,
  lib,
  ...
}:
pkgs.buildNpmPackage {
  pname = "context7";
  version = "0.3.13";

  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/ctx7/-/ctx7-0.3.13.tgz";
    hash = "sha256-dDaZfHwdReyOGD+Os9ybVRxxMP9WqdX2gBZ069vKOYk=";
  };

  # Generated via: cd <unpacked-src> && npm install --package-lock-only
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-mxbROzqWwMCfEdY7KZ2MCMWvry62oh5q9wB2bUl97hU=";

  dontNpmBuild = true;

  meta = with lib; {
    description = "Context7 CLI — fetch up-to-date library docs for AI tools";
    homepage = "https://github.com/upstash/context7";
    license = licenses.mit;
    mainProgram = "ctx7";
  };
}
