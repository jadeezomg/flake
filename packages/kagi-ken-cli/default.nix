{
  lib,
  pkgs,
}:
pkgs.buildNpmPackage rec {
  pname = "kagi-ken-cli";
  version = "1.7.0";

  src = pkgs.fetchFromGitHub {
    owner = "czottmann";
    repo = "kagi-ken-cli";
    rev = "1.7.0";
    hash = "sha256-qBLzraMLn0qTcHSIyor94+z7mbBzsudgT3b0MxD1M7g=";
  };

  # Vendored lock may use tarball URLs (see update.json patch_git_ssh_lock). Sync package.json deps from lock.
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
    node ${./sync-deps-from-lock.mjs}
  '';

  npmDepsHash = "sha256-zAO7CGQyci5b6VfEGfI+Bgzyham6wsys9r11HDJiAtw=";

  dontNpmBuild = true;

  meta = with lib; {
    description = "CLI for Kagi search and summarizer via session token (unofficial)";
    homepage = "https://github.com/czottmann/kagi-ken-cli";
    license = licenses.mit;
    mainProgram = "kagi-ken-cli";
  };
}
