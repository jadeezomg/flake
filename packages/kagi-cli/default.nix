{
  pkgs,
  lib,
  ...
}: let
  version = "0.10.0";

  # update_packages.py rewrites these top-level attrs for each release asset.
  linuxX64Hash = "sha256-rDTu21EXZcwwJwxfoHQM1Q5MwY+nDKlcY1DPdAbgiDA=";
  darwinArm64Hash = "sha256-kqkp3RgYJPhDTbI2Y40MJeGq2liyAT4QpOgxOth3xjE=";

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
      hash = info.hash;
    };

    # Tarball contains a single bare binary, not a subdirectory.
    sourceRoot = ".";

    nativeBuildInputs = lib.optionals pkgs.stdenv.isLinux [pkgs.autoPatchelfHook];
    buildInputs = lib.optionals pkgs.stdenv.isLinux [pkgs.stdenv.cc.cc.lib];

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
      platforms = ["x86_64-linux" "aarch64-darwin"];
      sourceProvenance = with sourceTypes; [binaryNativeCode];
    };
  }
