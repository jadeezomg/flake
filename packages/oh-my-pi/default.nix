{
  pkgs,
  lib,
  ...
}:
let
  version = "17.0.2";

  # update_packages.py rewrites these top-level attrs for each release asset.
  linuxX64Hash = "sha256-ZZUsz4eI8plWICA4cVJVNFMO5RFlRwL4IH+ivSOL10M=";
  darwinArm64Hash = "sha256-vQ+oTzby3FLgqrkfLYieU3g4kpo9Sah5ZGGjS3+dlmw=";

  # nixpkgs system → upstream release asset. Only packaged host systems are mapped.
  platforms = {
    "x86_64-linux" = {
      asset = "omp-linux-x64";
      hash = linuxX64Hash;
    };
    "aarch64-darwin" = {
      asset = "omp-darwin-arm64";
      hash = darwinArm64Hash;
    };
  };

  hostSystem = pkgs.stdenv.hostPlatform.system;
  info =
    platforms.${hostSystem}
      or (throw "oh-my-pi: unsupported system ${hostSystem} (only x86_64-linux + aarch64-darwin are packaged)");
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "oh-my-pi";
  inherit version;

  src = pkgs.fetchurl {
    url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/${info.asset}";
    hash = info.hash;
  };

  dontUnpack = true;

  # Do not patchelf Bun standalone executables: the appended bundle/footer must
  # stay byte-identical or `omp` starts as bare Bun. Wrap the Linux binary with
  # the glibc loader instead; this also works without nix-ld.
  nativeBuildInputs = lib.optionals pkgs.stdenv.isLinux [ pkgs.makeWrapper ];
  buildInputs = lib.optionals pkgs.stdenv.isLinux [
    pkgs.stdenv.cc.cc.lib # libstdc++
    pkgs.zlib
  ];

  installPhase =
    if pkgs.stdenv.isDarwin then
      ''
        runHook preInstall
        install -Dm755 $src $out/bin/omp
        runHook postInstall
      ''
    else
      ''
        runHook preInstall
        install -Dm755 $src $out/libexec/omp
        mkdir -p $out/bin
        makeWrapper \
          ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 \
          $out/bin/omp \
          --add-flags "--library-path ${
            lib.makeLibraryPath [
              pkgs.stdenv.cc.cc.lib
              pkgs.zlib
              pkgs.glibc
            ]
          }" \
          --add-flags "$out/libexec/omp"
        runHook postInstall
      '';

  dontStrip = true;
  dontPatchELF = true;

  meta = with lib; {
    description = "oh-my-pi (omp) — coding agent CLI fork of pi-mono with batteries-included tooling";
    homepage = "https://github.com/can1357/oh-my-pi";
    license = licenses.mit;
    mainProgram = "omp";
    platforms = [
      "x86_64-linux"
      "aarch64-darwin"
    ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
