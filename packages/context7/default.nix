{
  pkgs,
  lib,
  ...
}:
pkgs.buildNpmPackage {
  pname = "context7";
  version = "0.5.5";

  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/ctx7/-/ctx7-0.5.5.tgz";
    hash = "sha256-WYKjhFk2tJ7X8yoh+X760GriKoX8C+cafIuPpQNknBg=";
  };

  # Generated via: cd <unpacked-src> && npm install --package-lock-only
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-lMaE1gi97TPWs7mP8mYRTAt+eS9CjCik2AOPxe37hCc=";

  dontNpmBuild = true;

  meta = with lib; {
    description = "Context7 CLI — fetch up-to-date library docs for AI tools";
    homepage = "https://github.com/upstash/context7";
    license = licenses.mit;
    mainProgram = "ctx7";
  };
}
