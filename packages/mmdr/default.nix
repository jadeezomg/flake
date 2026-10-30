# mmdr (mermaid-rs-renderer): renders Mermaid diagrams to SVG or PNG without a
# browser. Prebuilt release binary, the same pattern as gitoui.
#
# mmdr keeps a font cache in ~/.cache/mmdr (or $XDG_CACHE_HOME/mmdr). If you
# drop the package, delete that folder.
{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
}:
let
  version = "0.3.1";

  # update_packages.py rewrites these top-level attrs for each release asset.
  linuxX64Hash = "sha256-4dpHt1h2m/8huCpID61kCjuJOpD8DcMhVRSG+LUMcgA=";
  darwinArm64Hash = "sha256-Vi0CUMuFiK3v45iiPku99n8kKEnqjYiMOCaLzD7fMiM=";

  platforms = {
    "x86_64-linux" = {
      asset = "mmdr-x86_64-unknown-linux-gnu.tar.gz";
      hash = linuxX64Hash;
    };
    "aarch64-darwin" = {
      asset = "mmdr-aarch64-apple-darwin.tar.gz";
      hash = darwinArm64Hash;
    };
  };

  hostSystem = stdenvNoCC.hostPlatform.system;
  info =
    platforms.${hostSystem}
      or (throw "mmdr: unsupported system ${hostSystem} (only x86_64-linux + aarch64-darwin are packaged)");
in
stdenvNoCC.mkDerivation {
  pname = "mmdr";
  inherit version;

  src = fetchurl {
    url = "https://github.com/1jehuang/mermaid-rs-renderer/releases/download/v${version}/${info.asset}";
    inherit (info) hash;
  };

  # The tarball holds a single bare binary, not a subdirectory.
  sourceRoot = ".";

  nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall
    install -Dm755 mmdr $out/bin/mmdr
    runHook postInstall
  '';

  meta = {
    description = "Mermaid diagram renderer in pure Rust, without a browser";
    homepage = "https://github.com/1jehuang/mermaid-rs-renderer";
    license = lib.licenses.mit;
    mainProgram = "mmdr";
    platforms = [
      "x86_64-linux"
      "aarch64-darwin"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
