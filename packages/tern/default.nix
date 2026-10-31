# Stencil's closed-beta terminal. build.stencil.so serves the tarball only
# after a Stencil sign-in, so Nix cannot download it. requireFile finds the
# file in the store by its hash instead. No update.json for the same reason.
#
# Tern updates itself from build.stencil.so, but it cannot replace a binary in
# the Nix store. Turn off "Update automatically" in Tern's settings once. For
# a new build, download the tarball, add it to the store, and bump version,
# build and hash here.
#
# Removal: Tern can write hidden autostart entries and icons under ~/.config
# and ~/.local/share. Dropping Tern leaves those and ~/.config/tern behind.
# Trash them by hand.
{
  lib,
  stdenv,
  stdenvNoCC,
  requireFile,
  autoPatchelfHook,
  copyDesktopItems,
  makeDesktopItem,
  libglvnd,
  vulkan-loader,
  wayland,
  libxkbcommon,
  libxcb,
  linux-pam,
  libpulseaudio,
}:
let
  version = "0.9.9";
  # The build id in the download path on build.stencil.so.
  build = "20261031-151729-9c1c09f";
  name = "Tern-${version}-linux-x86_64.tar.gz";
in
stdenvNoCC.mkDerivation {
  pname = "tern";
  inherit version;

  src = requireFile {
    inherit name;
    hash = "sha256-BFZbLabiMvTKHKQKLlaqKKJvifwQlGNJBlhGMeQTmT8=";
    message = ''
      Tern is a closed beta. Sign in to Stencil, download
        https://build.stencil.so/d/tern/${build}/${name}
      and add it to the Nix store on this host:
        nix-store --add-fixed sha256 ~/Downloads/${name}
    '';
  };

  nativeBuildInputs = [
    autoPatchelfHook
    copyDesktopItems
  ];
  buildInputs = [ stdenv.cc.cc.lib ];

  # Tern dlopens these, so they are not in DT_NEEDED and autoPatchelf must put
  # them on the RPATH itself.
  runtimeDependencies = [
    libglvnd
    vulkan-loader
    wayland
    libxkbcommon
    libxcb
    linux-pam
    libpulseaudio
  ];

  # Upstream ships it stripped; the Arch package also skips strip.
  dontStrip = true;

  # The tarball has no launcher entry or icon. The entries Tern writes itself
  # are hidden autostart entries.
  desktopItems = [
    (makeDesktopItem {
      name = "so.stencil.tern";
      desktopName = "Tern";
      comment = "Multiplexing terminal (closed beta)";
      exec = "tern";
      icon = "utilities-terminal";
      startupWMClass = "so.stencil.tern";
      categories = [
        "System"
        "TerminalEmulator"
      ];
      keywords = [
        "terminal"
        "shell"
      ];
    })
  ];

  installPhase = ''
    runHook preInstall
    install -Dm755 tern $out/bin/tern
    runHook postInstall
  '';

  meta = {
    description = "Native multiplexing terminal with panes that outlive the window (closed beta)";
    homepage = "https://stencil.so/tern";
    license = lib.licenses.unfree;
    mainProgram = "tern";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
