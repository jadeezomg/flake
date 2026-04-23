{
  pkgs,
  lib,
  ...
}:
pkgs.buildNpmPackage rec {
  pname = "pi-coding-agent";
  version = "0.69.0";

  # Published bundle (includes dist/); newer than nixpkgs @mariozechner/pi-coding-agent.
  src = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@mariozechner/pi-coding-agent/-/pi-coding-agent-0.69.0.tgz";
    hash = "sha256-b+1Rli77V/dRqgVAN7+qqqN57P/MUXxM4Wx35ZADU0U=";
  };

  # Generated: unpack tgz, cd package, npm install --package-lock-only
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-8cZjACRXmxdsLsqGsc84whLnP1GEozNobtiE42bQrBM=";

  dontNpmBuild = true;

  meta = with lib; {
    description = "Pi terminal coding agent (npm @mariozechner/pi-coding-agent)";
    homepage = "https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent";
    license = licenses.mit;
    mainProgram = "pi";
  };
}
