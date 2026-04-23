{
  pkgs,
  lib,
  ...
}: let
  version = "0.0.1776975379-gfcf58c";
  linuxX64Hash = "sha256-uLnXxGE951NpcntxsyaAMeP2iVTX9xrMiZL/4WtN08s=";
  linuxArm64Hash = "sha256-YqmL1Eredx9cPM/XZOkomzVZaTsOZKo7o3iOrUvrgFk=";
  darwinArm64Hash = "sha256-DjLaws6r/3WHsUGIwA7ZqdkF4/78+M4d6j/oBWGNsy8=";

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
