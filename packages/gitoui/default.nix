# Prebuilt release binary, the same pattern as kagi-cli.
#
# gitoui checks crates.io once a day and offers to update itself through
# upstream's install.sh, which writes a second copy to ~/.local/bin. Answer N
# to that prompt once. gitoui then writes `check_updates = false` to its own
# config.toml. Do not manage that file with Home Manager, because gitoui
# writes to it.
{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
}:
let
  version = "0.3.6";

  # update_packages.py rewrites these top-level attrs for each release asset.
  linuxX64Hash = "sha256-dht+3WjvMeq75vj0lG1jNdd8uACC86XUo7Lvum0IDuc=";
  darwinArm64Hash = "sha256-zVb7kGyGb/UL+n89UEzzCKD3h0CrHbY1cg8ZFBMKq4k=";

  platforms = {
    "x86_64-linux" = {
      asset = "gitoui-${version}-x86_64-unknown-linux-gnu.tar.gz";
      hash = linuxX64Hash;
    };
    "aarch64-darwin" = {
      asset = "gitoui-${version}-aarch64-apple-darwin.tar.gz";
      hash = darwinArm64Hash;
    };
  };

  hostSystem = stdenvNoCC.hostPlatform.system;
  info =
    platforms.${hostSystem}
      or (throw "gitoui: unsupported system ${hostSystem} (only x86_64-linux + aarch64-darwin are packaged)");
in
stdenvNoCC.mkDerivation {
  pname = "gitoui";
  inherit version;

  src = fetchurl {
    url = "https://github.com/NayJi7/gitoui/releases/download/v${version}/${info.asset}";
    inherit (info) hash;
  };

  # The tarball holds a single bare binary, not a subdirectory.
  sourceRoot = ".";

  nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall
    install -Dm755 gitoui $out/bin/gitoui
    runHook postInstall
  '';

  meta = {
    description = "Terminal git client with commit graph, staging, rebase, and GitHub PRs";
    homepage = "https://github.com/NayJi7/gitoui";
    license = lib.licenses.mit;
    mainProgram = "gitoui";
    platforms = [
      "x86_64-linux"
      "aarch64-darwin"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
