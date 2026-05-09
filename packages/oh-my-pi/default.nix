{
  pkgs,
  lib,
  ...
}: let
  version = "14.8.1";

  # Hashes per upstream release asset. Keep these top-level and named exactly
  # after `linuxX64Hash` / `darwinArm64Hash` so update_packages.py's
  # `binary_channel` handler can rewrite them via _replace_attr_once.
  linuxX64Hash = "sha256-W/MK0Ax4HF3xl5GW76zqSseRY8em9jmnhTdUEKIV1ww=";
  darwinArm64Hash = "sha256-HJYYuG/xJN4ltfLuStRkPtmyGol0I2dXSZ2Plb8E7DE=";

  # nixpkgs system → upstream asset mapping. We deliberately don't ship
  # darwin-x64 or linux-arm64 — neither matches a host in this flake.
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

    # IMPORTANT: do NOT patchelf the binary directly.
    #
    # Bun-compiled standalone executables append the JS bundle (zstd-compressed)
    # plus a footer with magic bytes after the ELF. The runtime scans the file
    # at startup for that footer to locate the embedded bundle. patchelf
    # rewrites ELF section offsets and shuffles the layout — even with the
    # binary still 512 MB on disk and "not stripped", the appended footer
    # ends up in a position Bun no longer finds, and `omp` falls through to
    # bare Bun help text instead of running the coding agent.
    #
    # Solution: keep the upstream blob byte-identical. Wrap it with a tiny
    # shell script that invokes the right glibc loader directly. NixOS's
    # nix-ld (modules/nixos/nix-ld.nix) provides the same libraries, but a
    # self-contained wrapper here means the package works without nix-ld too
    # (Darwin doesn't have it; non-NixOS dev shells don't either).
    nativeBuildInputs = lib.optionals pkgs.stdenv.isLinux [pkgs.makeWrapper];
    buildInputs = lib.optionals pkgs.stdenv.isLinux [
      pkgs.stdenv.cc.cc.lib # libstdc++
      pkgs.zlib
    ];

    installPhase =
      if pkgs.stdenv.isDarwin
      then ''
        runHook preInstall
        install -Dm755 $src $out/bin/omp
        runHook postInstall
      ''
      else ''
        runHook preInstall
        install -Dm755 $src $out/libexec/omp
        mkdir -p $out/bin
        makeWrapper \
          ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 \
          $out/bin/omp \
          --add-flags "--library-path ${lib.makeLibraryPath [pkgs.stdenv.cc.cc.lib pkgs.zlib pkgs.glibc]}" \
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
      platforms = ["x86_64-linux" "aarch64-darwin"];
      sourceProvenance = with sourceTypes; [binaryNativeCode];
    };
  }
