{
  pkgs,
  lib,
  ...
}:
pkgs.buildNpmPackage {
  pname = "context7";
  version = "0.4.3";

  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/ctx7/-/ctx7-0.4.3.tgz";
    hash = "sha256-DeruGRWV5/Zs7PlSbUA75eChuBxhAft2l3PVBrwz6fU=";
  };

  # Generated via: cd <unpacked-src> && npm install --package-lock-only
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-1ZXrigy5nEsfWfcg7lzyoCqLXsBGHFd71awtrRJwNOo=";

  dontNpmBuild = true;

  meta = with lib; {
    description = "Context7 CLI — fetch up-to-date library docs for AI tools";
    homepage = "https://github.com/upstash/context7";
    license = licenses.mit;
    mainProgram = "ctx7";
  };
}
