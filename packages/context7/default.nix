{
  pkgs,
  lib,
  ...
}:
pkgs.buildNpmPackage {
  pname = "context7";
  version = "0.4.4";

  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/ctx7/-/ctx7-0.4.4.tgz";
    hash = "sha256-huut/u97hbpQqyoeChbT75s35PzNI9ZNk+sOJTi6mp0=";
  };

  # Generated via: cd <unpacked-src> && npm install --package-lock-only
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-4ikWkwiJTgidXBbAY+PQRwdhIj8Yo2VuL1Y94hk6AQs=";

  dontNpmBuild = true;

  meta = with lib; {
    description = "Context7 CLI — fetch up-to-date library docs for AI tools";
    homepage = "https://github.com/upstash/context7";
    license = licenses.mit;
    mainProgram = "ctx7";
  };
}
