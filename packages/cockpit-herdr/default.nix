# cockpit (github.com/quaresc/cockpit): shows every coding agent that herdr or
# Herdr.app runs, with its ticket, pull request and CI run. Named cockpit-herdr,
# because nixpkgs `cockpit` is the Linux server web console. Prebuilt release
# archive, the same pattern as mmdr.
#
# $out/bin/cockpit is the program, and $out/app holds the Herdr.app layouts,
# mod and keys of the same version. `cockpit app install` finds $out/app,
# because it looks two folders above its binary. The package leaves out the
# Electron side browser (browser/, which imports browser cookies) and the update
# scripts, so cockpit cannot replace itself. Nix updates it with
# `just update-packages`.
#
# The release archive lacks three parts of the source, so ./notifier, ./themes
# and ./prune-browsers.sh are copies from the v1.6.1 source (herdr/notifier,
# app/themes, herdr/prune-browsers.sh). cockpit's doctor builds
# ~/.config/cockpit/Cockpit.app from $out/notifier/build.sh and counts leftover
# browser daemons with $out/prune-browsers.sh. `cockpit app install` copies
# $out/app/themes. After an update, compare these copies with the new tag.
#
# Mutable state: modules/profiles/apps/terminals/cockpit.nix runs
# `cockpit app install`, and cockpit writes its own state. If you drop the
# package, delete:
#   ~/.config/herdr-app/layouts/cockpit.json, cockpit.svg, cockpit-chat.json,
#     cockpit-chat.svg, ~/.config/herdr-app/mods/cockpit,
#     ~/.config/herdr-app/themes/cockpit-chat.json, cockpit-chat-light.json,
#     ~/.config/herdr-app/cockpit.json
#   the "layout:cockpit" and "layout:cockpit-chat" sections of
#     ~/.config/herdr-app/keys.json
#   ~/.cache/cockpit and ~/.config/cockpit
{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
}:
let
  version = "1.6.1";

  # update_packages.py rewrites these top-level attrs for each release asset.
  linuxX64Hash = "sha256-yGOR6r9n49SIF9jYulqt3P/xRppkhRGMiXmDcXbvYtQ=";
  darwinArm64Hash = "sha256-+/QW4brpw72aOyvBXV02p7r5gcczrOhnTuACC9+K2YQ=";

  platforms = {
    "x86_64-linux" = {
      asset = "cockpit-apps-${version}-x86_64-unknown-linux-gnu.tar.gz";
      hash = linuxX64Hash;
    };
    "aarch64-darwin" = {
      asset = "cockpit-apps-${version}-aarch64-apple-darwin.tar.gz";
      hash = darwinArm64Hash;
    };
  };

  hostSystem = stdenvNoCC.hostPlatform.system;
  info =
    platforms.${hostSystem}
      or (throw "cockpit-herdr: unsupported system ${hostSystem} (only x86_64-linux + aarch64-darwin are packaged)");
in
stdenvNoCC.mkDerivation {
  pname = "cockpit-herdr";
  inherit version;

  src = fetchurl {
    url = "https://github.com/quaresc/cockpit/releases/download/v${version}/${info.asset}";
    inherit (info) hash;
  };

  # The archive holds the binary and app/ at its top, not in a subdirectory.
  sourceRoot = ".";

  nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  # The macOS binary is ad-hoc signed. Stripping it would break the signature.
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 cockpit $out/bin/cockpit
    mkdir -p $out/app
    cp -r app/layouts app/mods app/keys.json $out/app/
    cp -r --no-preserve=mode ${./themes} $out/app/themes
    cp -r --no-preserve=mode ${./notifier} $out/notifier
    install -m644 ${./prune-browsers.sh} $out/prune-browsers.sh
    runHook postInstall
  '';

  meta = {
    description = "See every coding agent that herdr or Herdr.app runs, and what it works on";
    homepage = "https://github.com/quaresc/cockpit";
    license = lib.licenses.mit;
    mainProgram = "cockpit";
    platforms = [
      "x86_64-linux"
      "aarch64-darwin"
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
