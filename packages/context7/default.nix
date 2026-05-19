{
  pkgs,
  lib,
  ...
}:
pkgs.buildNpmPackage {
  pname = "context7";
  version = "0.4.2";

  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/ctx7/-/ctx7-0.4.2.tgz";
    hash = "sha256-qqZv8QYfjpqRTOxZR8X7wpiO4bgfjJvDwuTFGnhZz1s=";
  };

  # Generated via: cd <unpacked-src> && npm install --package-lock-only
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-G44CH4Z6iXg7F20/+wJDOmIHzmiEoh63DkKTe73M2t8=";

  dontNpmBuild = true;

  meta = with lib; {
    description = "Context7 CLI — fetch up-to-date library docs for AI tools";
    homepage = "https://github.com/upstash/context7";
    license = licenses.mit;
    mainProgram = "ctx7";
  };
}
