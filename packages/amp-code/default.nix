{
  pkgs,
  lib,
  ...
}: let
  version = "0.0.1776989558-g854fcb";
  linuxX64Hash = "sha256-rOo0BsMMSLLCDGbSl5u4uvlh9rNf9iH2D5DzFrH1nJI=";
  linuxArm64Hash = "sha256-3kDDAnc9baBESlV9eQFFDsyrqNCBhU2qHs4LAnq4SjM=";
  darwinArm64Hash = "sha256-jYWOggVagNAU8MMnGwnmbkNhIRTy3pnUUuv8xgPpRXQ=";

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
