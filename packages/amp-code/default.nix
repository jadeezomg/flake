{
  pkgs,
  lib,
  ...
}: let
  version = "0.0.1776788459-gfad969";
  linuxX64Hash = "sha256-Ap2MzHasjQSqQ+YtX6MbCuNy10Hn5bk31ujkAJQ2PUU=";
  linuxArm64Hash = "sha256-GrS+IzEDS1IBiAqo9mRu+m8vm694lG03GEEsZvyGkU4=";
  darwinArm64Hash = "sha256-t3brPFjexdmAK7pRA746DVdWd62sUbvVd8SSabDA6BE=";

  platform =
    if pkgs.stdenv.hostPlatform.isLinux && pkgs.stdenv.hostPlatform.isx86_64
    then "linux-x64"
    else if pkgs.stdenv.hostPlatform.isLinux && pkgs.stdenv.hostPlatform.isAarch64
    then "linux-arm64"
    else if pkgs.stdenv.hostPlatform.isDarwin && pkgs.stdenv.hostPlatform.isAarch64
    then "darwin-arm64"
    else throw "Unsupported platform for amp-code: ${pkgs.stdenv.hostPlatform.system}";

  hashes = {
    linux-x64 = linuxX64Hash;
    linux-arm64 = linuxArm64Hash;
    darwin-arm64 = darwinArm64Hash;
  };
in
  pkgs.stdenvNoCC.mkDerivation {
    pname = "amp-code";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://static.ampcode.com/cli/${version}/amp-${platform}";
      hash = hashes.${platform};
    };

    dontUnpack = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 "$src" "$out/bin/amp"
      runHook postInstall
    '';

    meta = with lib; {
      description = "Amp Code CLI";
      homepage = "https://ampcode.com";
      license = licenses.unfree;
      mainProgram = "amp";
      platforms = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
    };
  }
