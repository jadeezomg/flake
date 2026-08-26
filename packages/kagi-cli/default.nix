{
  pkgs,
  lib,
  ...
}:
let
  version = "0.18.1";

  # update_packages.py rewrites these top-level attrs for each release asset.
  linuxX64Hash = "sha256-My65QvZ8UenIyZM+5D7c0cNv8fAheTnQ1r2Bv1YkLcI=";
  darwinArm64Hash = "sha256-pjYuj6Kk2gcDA+RRigqR2S760F+XCaIpCbLl/0YWXoM=";

  platforms = {
    "x86_64-linux" = {
      asset = "kagi-v${version}-x86_64-unknown-linux-gnu.tar.gz";
      hash = linuxX64Hash;
    };
    "aarch64-darwin" = {
      asset = "kagi-v${version}-aarch64-apple-darwin.tar.gz";
      hash = darwinArm64Hash;
    };
  };

  hostSystem = pkgs.stdenv.hostPlatform.system;
  info =
    platforms.${hostSystem}
      or (throw "kagi-cli: unsupported system ${hostSystem} (only x86_64-linux + aarch64-darwin are packaged)");
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "kagi-cli";
  inherit version;

  src = pkgs.fetchurl {
    url = "https://github.com/Microck/kagi-cli/releases/download/v${version}/${info.asset}";
    inherit (info) hash;
  };

  # Tarball contains a single bare binary, not a subdirectory.
  sourceRoot = ".";

  nativeBuildInputs = lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.autoPatchelfHook ];
  buildInputs = lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall
    install -Dm755 kagi $out/bin/kagi
    runHook postInstall
  '';

  meta = with lib; {
    description = "Terminal CLI for Kagi — search, summarize, assistant, and more";
    homepage = "https://github.com/Microck/kagi-cli";
    license = licenses.mit;
    mainProgram = "kagi";
    platforms = [
      "x86_64-linux"
      "aarch64-darwin"
    ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
