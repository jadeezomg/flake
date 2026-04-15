{
  lib,
  pkgs,
}:
pkgs.buildNpmPackage rec {
  pname = "kagi-ken";
  version = "1.3.0";

  src = pkgs.fetchFromGitHub {
    owner = "czottmann";
    repo = "kagi-ken";
    rev = "1.3.0";
    hash = "sha256-SyeqBAj2kSsA2Q8ebDUYi6/pihBT5hOKlqP9z7wHoYY=";
  };

  npmDepsHash = "sha256-2FTS2cQ4it10lO213dwR9zXzf43D2a9zkTxWSVfIoiI=";

  dontNpmBuild = true;

  meta = with lib; {
    description = "Node library for Kagi search and summarizer via session token (unofficial)";
    homepage = "https://github.com/czottmann/kagi-ken";
    license = licenses.mit;
  };
}
